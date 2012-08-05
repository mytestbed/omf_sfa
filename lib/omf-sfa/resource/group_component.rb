require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource
  
  # A +GroupComponent+ is a group with a component interface. This allows it
  # to be addressed and used in an SFA context.
  #
  class GroupComponent < OGroup
    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods
    
    sfa_class 'group'
    sfa :component_id, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    sfa :component_manager_id, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
    sfa :component_name, :attribute => true # "plane

    sfa :components, :has_many => true, :include_level => 0 # only include components when top group
    
    def components
      self.contains_resources
    end
    
    def _to_sfa_components_property_hash(resources, pdef, href2obj, opts)
      opts = opts.dup
      # TODO: What was that used for? Does this assume that prefix include slice name?
      #opts[:href_prefix] = (opts[:href_prefix] || '/') + 'resources/'
      resources.collect do |o|
        o.to_sfa_hash(href2obj, opts)
      end
    end

  end
  
end # OMF::SFA::Resource