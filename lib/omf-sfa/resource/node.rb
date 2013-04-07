
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/interface'

module OMF::SFA::Resource
  
  class Node < OComponent
    

    oproperty :hardware_type, String, :required => false
    oproperty :available, Boolean, :default => true
    #oproperty :sliver_type, String, :required => false
    oproperty :interfaces, :interface, :functional => false
    oproperty :exclusive, Boolean, :default => true
    #belongs_to :sliver

    sfa_class 'node'
    sfa :hardware_type, :inline => true, :has_many => true
    sfa :available, :attr_value => 'now'  # <available now="true">
    #sfa :sliver_type, :attr_value => 'name'
    sfa :interfaces, :inline => true, :has_many => true
    sfa :exclusive, :attribute => true
    
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
    
    def _to_sfa_interfaces_property_hash(interfaces, pdef, href2obj, opts)
      # opts = opts.dup
      # opts[:href_prefix] = (opts[:href_prefix] || '/') + 'interfaces/'
      interfaces.collect do |o|
        o.to_sfa_hash(href2obj, opts)
      end
    end
    
    before :save do
      resource_type |= 'node'
    end
    
  end
  
end # OMF::SFA

