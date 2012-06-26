

require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource
  
      # <link component_id="urn:publicid:IDN+emulab.net+link+link-pc102%3Aeth2-internet%3Aborder" component_name="link-pc102:eth2-internet:border">    
        # <component_manager name="urn:publicid:IDN+emulab.net+authority+cm"/>    
          # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>    
          # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>    
        # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+internet:border" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>    
        # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>    
          # <link_type name="ipv4"/>    
      # </link>  
  
  # This class defines a group of resources which can be described through
  # an extension of RSpec
  #
  class CompGroup < OGroup
    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'omf:group'

    sfa :component_id, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    sfa :component_manager_id, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
    sfa :component_name, :attribute => true # "plane
    
    def to_sfa_xml(parent, obj2id = {}, opts = {})
      gel = _to_sfa_xml(parent, obj2id, opts)
      self.each_resource do |r|
        puts "CHILD #{r}"
        r.to_sfa_xml(gel, obj2id, opts)
      end
      parent
    end    
  end
  
end # OMF::SFA::Resource

