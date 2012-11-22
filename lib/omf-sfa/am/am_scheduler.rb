
require 'omf_common/lobject'
require 'omf-sfa/resource'
require 'omf-sfa/resource/comp_group'
require 'active_support/inflector'


module OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Common::LObject

    def create_resource(resource_descr, type_to_create, authorizer)
      if type_to_create.nil?
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
      else
	#resource_descr[:account] = authorizer.account
	olease = resource_descr.delete(:lease)

	resource_descr[:resource_type] = type_to_create
	type = type_to_create.camelize
	resource = eval("OMF::SFA::Resource::#{type}").new(resource_descr)
	resource.leases << olease if olease
	resource.save
	resource
      end

    end

    def release_resource(resource, authorizer)
      unless resource.is_a? OMF::SFA::Resource::OResource
	raise "Expected OResource but got '#{resource.inspect}"
      end

      resource = resource.destroy!
      raise "Failed to destroy resource" unless resource
      resource
    end

    def get_nil_account()
      @nil_account
    end

    def initialize()
      @nil_account = OMF::SFA::Resource::OAccount.new(:name => '__default__', :valid_until => Time.now + 1E10)
    end    

  end # OMFManager

end # OMF::SFA::AM
