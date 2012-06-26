#
# Populate an AM database with a simple topology
#

require 'rubygems'
require 'data_mapper'
require 'nokogiri'
require 'omf-common/mobject2'

require 'omf-sfa/resource'

ROUTERS = 3
NODES_PER_ROUTER = 2


OMF::Common::Loggable.init_log 'sample_tb'

include OMF::SFA::Resource

GURN.default_prefix = "urn:publicid:IDN+acme.org"
# Component.default_domain = "acme.org"
# Component.default_component_manager_id = "authority+am"

# Configure the data store
#
DataMapper::Logger.new($stdout, :note)
#path = ARGV[2] || '/tmp/am_test2'
#DataMapper.setup(:default, :adapter => 'yaml', :path => path)
DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
DataMapper::Model.raise_on_save_failure = true 

#puts DataMapper::SubjectSet.entries.inspect

DataMapper::Model.descendants.each do |m| puts m.inspect end
puts '-----------'
Node.descendants.each do |m| puts m.inspect end
puts '-----------'
  

DataMapper.finalize
DataMapper.auto_upgrade!

sliver = OMF::SFA::Resource::Sliver.def_sliver

routers = []

ROUTERS.times do |ri|
  rname = "r#{ri}"
  r = Node.create(:name => rname, :sliver => sliver)
  routers << r
  NODES_PER_ROUTER.times do |ni|
    name = "c#{ri}_#{ni}"
    n = Node.create(:name => name, :sliver => sliver)
    l = Link.create(:name => "la#{ri}_#{ni}", :sliver => sliver)
    i1 = Interface.create(:node => r, :channel => l)
    i2 = Interface.create(:node => n, :channel => l)
  end
end

ROUTERS.times do |i|
  (i + 1 .. ROUTERS - 1).each do |j|
    l = Link.create(:name => "l#{i}_#{j}", :sliver => sliver)
    i1 = Interface.create(:node => routers[i], :channel => l)
    i2 = Interface.create(:node => routers[j], :channel => l)
  end
end


