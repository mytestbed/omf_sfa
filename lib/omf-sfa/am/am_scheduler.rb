
require 'omf_base/lobject'
require 'omf-sfa/resource'
require 'omf-sfa/resource/comp_group'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_liaison'
require 'active_support/inflector'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements a default resource scheduler
  #
  class AMScheduler < OMF::Base::LObject

    # Create a resource of specific type given its description in a hash. If the type
    # or the resource is physical then we create a clone of itself and assign it to
    # the user who asked for it (conceptually a physical resource even though it is exclusive,
    # is never given to the user but instead we provide him a clone of the resource).
    # If the type is a 'lease' then we normally create a lease object.
    #
    # @param [Hash] resource_descr contains the properties of the new resource
    # @param [String] The type of the resource we want to create
    # @param [Hash] oproperties is a hash with all the OProperty values of the new resource
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] Returns the created resource
    #
    def create_resource(resource_descr, type_to_create, oproperties, authorizer)
      debug "create_resource: resource_descr:'#{resource_descr}' type_to_create:'#{type_to_create}' oproperties:'#{oproperties}' authorizer:'#{authorizer.inspect}'"
      if type_to_create.eql?('node')
        desc = resource_descr.dup
        desc[:account] = get_nil_account()

        type = type_to_create.camelize

        base_resource = eval("OMF::SFA::Resource::#{type}").first(desc)

        if base_resource.nil? || !base_resource.available
          raise UnknownResourceException.new "Resource '#{desc.inspect}' is not available or doesn't exist"
        end

        # create a clone
        vr = base_resource.clone

        vr.account = authorizer.account
        vr.provided_by = base_resource
        vr.save

        base_resource.provides << vr
        base_resource.save

        return vr
      elsif type_to_create.eql?('OLease')
        resource_descr[:resource_type] = type_to_create
        lease = OMF::SFA::Resource::OLease.create(resource_descr)
        lease.valid_from = oproperties[:valid_from]
        lease.valid_until = oproperties[:valid_until]
        #lease.status = :pending
        raise UnavailableResourceException.new "Cannot create '#{resource_descr.inspect}'" unless lease.save
        return lease
      else
        raise "Uknown type of resource '#{type_to_create}'. Expected one of 'Node' or 'OLease'"
      end
    end

    # Releases/destroys the given resource
    #
    # @param [OResource] The actual resource we want to destroy
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Boolean] Returns true for success otherwise false
    #
    def release_resource(resource, authorizer)
      debug "release_resource: resource-> '#{resource.to_json}'"
      unless resource.is_a? OMF::SFA::Resource::OResource
        raise "Expected OResource but got '#{resource.inspect}'"
      end

      base = resource.provided_by

      unless resource.leases.empty?
        base.leases.each do |l|
          if (l.id == resource.leases.first.id)
            time = Time.now
            if (l.valid_until <= time)
              l.status = "past"
            else
              l.status = "cancelled"
            end
          end
        end
        msg = resource.leases.first.component_leases.destroy!
        raise "Failed to destroy component_leases" unless msg
      end
      resource = resource.destroy!
      raise "Failed to destroy resource" unless resource
      resource
    end

    # Accept or reject the reservation of the component
    #
    # @param [OLease] lease contains the corresponding reservation window
    # @param [OComponent] component is the resource we want to reserve
    # @return [Boolean] returns true or false depending on the outcome of the request
    #
    def lease_component(lease, component)
      # TODO: Implement a basic FCFS for the competing leases of a component.
      # Basic Component provides itself(clones) so many times as the accepted leases on it.
      debug "lease_component: lease:'#{lease.name}' to component:'#{component.name}'"

      base = component.provided_by
      base.leases.each do |l|
        if (lease.valid_from >= l.valid_until || lease.valid_until <= l.valid_from)
          #all ok, do nothing
        elsif (lease.valid_from <= l.valid_from && lease.valid_until > l.valid_from)#overlapping time
          raise UnavailableResourceException.new "Cannot lease '#{component.name}', because it is unavailable for the requested time."
        elsif (lease.valid_from >= l.valid_from && lease.valid_from <= l.valid_until)#overlapping time
          raise UnavailableResourceException.new "Cannot lease '#{component.name}', because it is unavailable for the requested time."
        end
      end
      lease.status = "accepted"
      base.leases << lease
      base.save
      component.leases << lease
      component.save
      #@am_liaison.enable_lease(lease, component)
      return true
    end

    # It returns the default account, normally used for admin account.
    #
    # @return [OAccount] returns the default account object
    #
    def get_nil_account()
        @nil_account
    end

    def initialize()
      @nil_account = OMF::SFA::Resource::OAccount.new(:name => '__default__', :valid_until => Time.now + 1E10)
      @am_liaison = OMF::SFA::AM::AMLiaison.new
    end

  end # OMFManager

end # OMF::SFA::AM
