
require 'omf_common/lobject'
require 'omf-sfa/resource'
require 'omf-sfa/resource/comp_group'

module OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Common::LObject
    
    def create_resource(resource_descr, type_to_create, authorizer)
      descr = resource_descr.dup
      desc[:account] = get_nil_account()
      bas_resource = OResource.first()
      unless !base_resource || base_resource.available
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist"              
      end
      
      # create a clone
      vr = base_resource.clone
      
      base_resource.available = false
      base_resource.provides << vr
      base_resource.save
      
      vr.provided_by = base_resource
      vr.account = authorizer.account

      return vr
    end

    def release_resource(resource, authorizer)
      unless resource.is_a? OMF::SFA::Resource::OResource
        raise "Expected OResource but got '#{resource.inspect}"
      end

      unless resource.account == authorizer.account
        raise InsufficientPrivilegesException.new("Can only release account owner's resource")
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
    
    def get_nil_account()
      @nil_account
    end
    
    def initialize()
      @nil_account = OAccount(:name => '__default__', :valid_until => Time.now + 1E10)
    end    
    
  end # OMFManager
    
end # OMF::SFA::AM