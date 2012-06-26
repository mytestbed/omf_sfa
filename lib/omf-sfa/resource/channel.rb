
require 'omf-sfa/resource/ocomponent'

module OMF::SFA::Resource

  class Channel < OComponent
    
    oproperty :interface, :interface, :functional => false
    
    sfa_class 'channel'
    sfa :interfaces, :inline => true, :has_many => true

    # Override xml serialization of 'interface' 
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'interfaces'
        value.each do |iface|
          iface.to_sfa_ref_xml(res_el, obj2id, opts)
        end
        return        
      end
      super
    end
    
  end
  
end # OMF::SFA
