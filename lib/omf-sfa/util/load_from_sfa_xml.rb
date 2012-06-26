
#
# Load a AM database from an SFA RSPEC
#

require 'rubygems'
require 'dm-core'
require 'nokogiri'
require 'omf-common/mobject2'



require 'omf-sfa/resource/sliver'
require 'omf-sfa/resource/node'
require 'omf-sfa/resource/link'
require 'omf-sfa/resource/gurn'

require 'omf-sfa/resource/sfa_base'
require 'omf-sfa/resource/node'
require 'omf-sfa/resource/interface'
require 'omf-sfa/resource/link'
require 'omf-sfa/resource/link_property'
require 'omf-sfa/resource/network'
require 'omf-sfa/resource/abstract_resource'
require 'omf-sfa/resource/component'
require 'omf-sfa/resource/abstract_resource'
require 'omf-sfa/resource/abstract_resource'

OMF::Common::Loggable.init_log 'load_rspec'






OMF::SFA::Resource::GURN.default_prefix = "urn:publicid:IDN+emulab.net"
OMF::SFA::Resource::Component.default_domain = "emulab.net"
OMF::SFA::Resource::Component.default_component_manager_id = "authority+cm"

#component_id="urn:publicid:IDN+emulab.net+node+cisco3" component_manager_id="urn:publicid:IDN+emulab.net+authority+cm" component_name="cisco3" exclusive="true"

unless fileName = ARGV[1]
  puts "Missing XML file name"
  exit -1
end

# Configure the data store
#
DataMapper::Logger.new($stdout, :debug)
path = ARGV[2] || '/tmp/am_test2'
puts path
DataMapper.setup(:default, :adapter => 'yaml', :path => path)
DataMapper::Model.raise_on_save_failure = true 

f = File.open(fileName)
doc = Nokogiri::XML(f)
f.close

DataMapper.finalize

sliver = OMF::SFA::Resource::Sliver.first_or_create(:name => '__UNASSIGNED__')
 
doc.xpath("//xmlns:node").each do |el|
  n = OMF::SFA::Resource::Node.first_or_create(:name => el['component_name'], :sliver => sliver)
  n.save
end

