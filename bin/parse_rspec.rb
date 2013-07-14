#!/usr/bin/env ruby

DESCR = %{
Read Rspec file and create internal object representation
}

BIN_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(BIN_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

require 'rubygems'
require 'optparse'
require 'dm-core'
require 'nokogiri'
require 'omf_common/lobject'
require 'json'

$verbose = false
$debug = false
$out_file_name = nil
$out_mode = 'dump'

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options] rspec_file\n#{DESCR}\n"
op.on '-r', '--resource-url URL', "URL of resource (e.g. xmpp://my.server.com/topic1)" do |url|
  resource_url = url
end
op.on '-m', '--out-mode MODE', "Mode determining what is being written out [#{$out_mode}]" do |mode|
  $out_mode = mode
end
op.on '-o', '--out OUT_FILE', "File to write result into [STDOUT]" do |fn|
  $out_file_name = fn
end
op.on '-d', '--debug', "Set log level to DEBUG" do
  $debug = true
end
op.on '-v', '--verbose', "Print out rspec snippets as we go along" do
  $verbose = true
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []

OMF::Common::Loggable.init_log 'parse_rspec'

unless in_file_name = (rest || [])[0]
  abort "Missing rspec file"
end
unless File.readable?(in_file_name)
  abort "Can't read file '#{in_file_name}"
end

rspec = Nokogiri::XML.parse(File.read(in_file_name)).root
#puts rspec

unless rspec.name.downcase == 'rspec'
  abort "Expected RSPEC, but document started with '#{rspec.name}"
end

# Initialise DataMapper
DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, :adapter => :in_memory)

#require 'json'
require 'omf-sfa/resource'
include OMF::SFA::Resource

DataMapper.finalize

# Process RSPEC
resources = []
context = {}
rspec.children.each do |el|
  next if el.is_a? Nokogiri::XML::Text
  if $verbose
    puts '------------------'
    puts el
  end
  n = nil
  begin
    n = OMF::SFA::Resource::OComponent.from_sfa(el, context)
  rescue Exception => ex
    puts "WARN: Couldn't parse '#{el.to_s[0 .. 30]}' - #{ex}"
    puts ex.backtrace
    exit
  end
  if n
    resources << n
    puts n.inspect if $verbose
    n.save
  end
  #n.create_from_xml(el, {})
end

def print_advertisement(resources)
  puts resources.inspect
  r = resources[0]
  puts r.save
  puts OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources)
  #puts r.to_sfa_xml
end

def interface_to_hash(interface)
  h = {node: interface.node.uuid}
  if interface.ip_addresses && interface.ip_addresses.length > 0
    h[:ip_address] = interface.ip_addresses[0].address
  end
  h
end

def print_json(resources)
  resources.each do |r|
    puts '================='
    r.urn
    #puts "#{r.type} (#{r.inspect})"\n
    puts "#{r.type}"
    r.to_sfa_hash.each do |k, v|
      puts "  #{k}: #{v}"
    end
  end
end

res = {}
case $out_mode.to_sym
when :dump
  resources = {}
  opts = {max_levels: 3}
  res = OMF::SFA::Resource::OComponent.find_all.map do |r|
    next if resources.include?(r)
    r.to_hash(resources, opts)
  end.compact

when :monitor
  resources = {}
  opts = {}
  res[:nodes] = OMF::SFA::Resource::Node.find_all.map do |r|
    h = r.to_hash(resources, opts)
    h.delete(:href)
    h.delete(:interfaces)
    h
  end
  #opts = {max_levels: 3}
  res[:links] = OMF::SFA::Resource::Link.find_all.map do |r|
    from, to = r.interfaces
    puts from.node
    h = r.to_hash(resources, opts)
    h.delete(:href)
    h.delete(:interfaces)
    h[:from] = interface_to_hash(from)
    h[:to] = interface_to_hash(to)
    h
  end

else
  puts "ERROR: Unknown output mode '#{$out_mode}'"
end

out = JSON.pretty_generate(res)
if $out_file_name
  puts "Writing result to '#{$out_file_name}'"
  f = File.open($out_file_name, 'w')
  f.write out
else
  puts '=========================='
  puts out
end


