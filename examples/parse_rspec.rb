#
# Read Rspec file and create internal object representation
#

require 'rubygems'
require 'dm-core'
require 'nokogiri'
require 'omf_common/lobject'
OMF::Common::Loggable.init_log 'parse_rspec'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, :adapter => :in_memory)
#DataMapper.setup(:default, :adapter => 'yaml', :path => '/tmp/test_yaml')

# DataMapper::Model.append_extensions(Pagination::ClassMethods)
# DataMapper::Model.append_inclusions(Pagination::InstanceMethods)

#require 'json'
require 'omf-sfa/resource'
include OMF::SFA::Resource

DataMapper.finalize


c = File.read(ARGV[0])
rspec = Nokogiri::XML.parse(c).root
#puts rspec

unless rspec.name.downcase == 'rspec'
  abort "Expected RSPEC, but document started with '#{rspec.name}"
end
resources = []
context = {}
rspec.children.each do |el|
  next if el.is_a? Nokogiri::XML::Text
  #puts ">>> #{el.methods.sort}"
  #puts ">>> #{el.children.methods.sort}"
  #el.children.find {|e| puts ">> #{e.class}" }
  puts '------------------'
  puts el
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
    puts n.inspect
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

#print_json(resources)
#print_json(OMF::SFA::Resource::OResource.find_all)
puts '=========================='
puts OMF::SFA::Resource::OResource.find_all.map {|r| r.to_hash}

# context.each do |n, r|
  # puts "#{n}: #{r.class}"
# end

