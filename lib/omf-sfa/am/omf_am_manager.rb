
require 'omf-sfa/am/dm_am_manager'

module OMF::SFA::AM
  


  # The manager is where all the AM related policies and 
  # resource management is concentrated. Testbeds with their own 
  # ways of dealing with resources and components should only 
  # need to extend this class.
  #
  # This implementation doesn't create new components, it simply shits them between
  # slices.
  #
  class OMFManager < DataMapperManager
    
    
    # Create a virtualize resource from 'base_resource' and return it.
    #
    def virtualize_resource(base_resource, resource_descr, opts)
      unless base_resource.available
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist"              
      end
      
      vr = base_resource.clone
      
      base_resource.available = false
      base_resource.provides << vr
      base_resource.save
      
      vr.provided_by = base_resource
      vr.account = get_requester_account(opts)

      return vr

    end
    
    # This methods deletes components, or more broadly defined, removes them
    # from a slice. 
    #
    # Currently, we simply transfer components to the +default_sliver+
    #    
    def delete_resource(resource_descr, opts)
      unless resource = find_resource(resource_descr, true, opts)
        raise UnknownResourceException("Can't find resource '#{resource_descr.inspect}")
      end
      if resource.account == get_default_account
        raise InsufficientPrivilegesException.new("Can't delete basic resource '#{resource.name}::#{resource.uuid}'")
      end
      if !resource.provides.empty?
        raise MissingImplementationException("Don't know yet how to delete resource which still provides other resources")
      end
      provider = resource.provided_by      
      r = resource.destroy!
      if provider.provides.empty?
        # This assumes that base resources can only provide one virtual resource
        # TODO: This doesn't really test if the provider is a base resource
        provider.available = true
        provider.save
      end
      r
    end      
    
    
  end # OMFManager
    
end # OMF::SFA::AM