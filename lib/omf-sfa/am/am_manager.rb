
require 'omf_common/lobject'
require 'omf-sfa/resource'
require 'omf-sfa/resource/comp_group'
require 'nokogiri'


module OMF::SFA::AM

  class AMManagerException < Exception; end
  class UnknownResourceException < AMManagerException; end
  class UnavailableResourceException < AMManagerException; end  
  class UnknownAccountException < AMManagerException; end  
  class FormatException < AMManagerException; end
  class ClosedAccountException < AMManagerException; end
  class InsufficientPrivilegesException < AMManagerException; end
  class UnavailablePropertiesException < AMManagerException; end
  class MissingImplementationException < Exception; end
  class UknownLeaseException < Exception; end

  OL_NAMESPACE = "http://schema.ict-openlab.eu/sfa/rspec/1"

  # The manager is where all the AM related policies and 
  # resource management is concentrated. Testbeds with their own 
  # ways of dealing with resources and components should only 
  # need to extend this class.
  #
  class AMManager < OMF::Common::LObject

    # Create an instance of this manager
    #
    # @param [Scheduler] scheduler to use for creating new resource
    #
    def initialize(scheduler)
      @scheduler = scheduler
    end

    ### MANAGEMENT INTERFACE: adding and removing from the AM's control

    # Register a resource to be managed by this AM.
    # 
    # @param [OResource] resource to have managed by this manager
    #
    def manage_resource(resource)
      unless resource.is_a?(OMF::SFA::Resource::OResource)
        raise "Needs to be a [OResource]"
      end 

      null_account = _get_nil_account
      resource.account = null_account
      resource.save
      # rg = get_root_group_for_account(def_account)
      # rg.contains_resources << resource
      # rg.save
      resource
    end

    # Register an array of resources to be managed by this AM.
    # 
    # @param [Array] array of resources
    #
    def manage_resources(resources)
      resources.each {|r| manage_resource(r) }
    end

    ### ACCOUNTS: creating, finding, and releasing accounts

    # Return the account described by +account_descr+. Create if it doesn't exist.
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OAccount] The requested account
    # @raise [UnknownResourceException] if requested account cannot be created
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_or_create_account(account_descr, authorizer)
      debug "find_or_create_account: '#{account_descr.inspect}'"
      begin
        return find_account(account_descr, authorizer)
      rescue UnavailableResourceException
      end
      authorizer.can_create_account?
      account = OMF::SFA::Resource::OAccount.create(account_descr)
      # We have an 1-to-1 relationship between account and project for the moment
      project = OMF::SFA::Resource::Project.create
      account.project = project
      account.save
      raise UnavailableResourceException.new "Cannot create '#{account_descr.inspect}'" unless account 
      account
    end

    # Return the account described by +account_descr+. Create if it doesn't exist.
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OAccount] The requested account
    # @raise [UnknownResourceException] if requested account cannot be found
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_account(account_descr, authorizer)
      unless account = OMF::SFA::Resource::OAccount.first(account_descr)
        raise UnavailableResourceException.new "Unknown account '#{account_descr.inspect}'"
      end
      authorizer.can_view_account?(account)
      account
    end

    # Return all accounts visible to the requesting user
    #
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OAccount>] The visible accounts (maybe empty)
    #
    def find_all_accounts(authorizer)
      accounts = OMF::SFA::Resource::OAccount.all() 
      nil_account = _get_nil_account()
      accounts.map do |a|
        next if a == nil_account
        begin 
          authorizer.can_view_account?(a)
          a
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Return the account described by +account_descr+ if it is active.
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OAccount] The requested account
    # @raise [UnknownResourceException] if requested account cannot be found 
    # @raise [UnavailableResourceException] if requested account is closed 
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_active_account(account_descr, authorizer)
      account = find_account(account_descr, authorizer)
      if account.closed?
        raise UnavailableResourceException.new "Account '#{account.inspect}' is closed"
      end
      account
    end

    # Renew account described by +account_descr+ hash until +expiration_time+.
    # ALready closed or expired accounts can't be renewed.
    #
    # @param [Hash] properties of account
    # @param [Time] time until account should remain valid  
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OAccount] The requested account
    # @raise [UnknownResourceException] if requested account cannot be found 
    # @raise [UnavailableResourceException] if requested account is closed 
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def renew_account_until(account_descr, expiration_time, authorizer)    
      account = find_active_account(account_descr, authorizer)
      authorizer.can_renew_account?(account, expiration_time)
      account.valid_until = expiration_time
      account.save
      account
    end

    # Close the account described by +account+ hash.
    #
    # Make sure that all associated resources are freed as well
    #
    # @param [Hash] properties of account
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OAccount] The closed account
    # @raise [UnknownResourceException] if requested account cannot be found 
    # @raise [UnavailableResourceException] if requested account is closed 
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def close_account(account_descr, authorizer)
      account = find_active_account(account_descr, authorizer)
      authorizer.can_close_account?(account)
      # TODO: Free all resources associated with this account!!!!
      # OMF::SFA::Resource::OComponent.all(:account => account).each do |c|
      # c.account = def_account
      # c.save
      # end
      account.close
      account.save
      account
    end

    ### USERS

    # Return the user described by +user_descr+. Create if it doesn't exist.
    #
    # Note: This is an unprivileged  operation as creating a user doesn't imply anything
    # else beyond opening a record.
    #
    # @param [Hash] properties of user
    # @return [User] The requested user
    # @raise [UnknownResourceException] if requested user cannot be created
    #
    def find_or_create_user(user_descr)
      debug "find_or_create_user: '#{user_descr.inspect}'"
      begin
        return find_user(user_descr)
      rescue UnavailableResourceException
      end
      user = OMF::SFA::Resource::User.create(user_descr)
      raise UnavailableResourceException.new "Cannot create '#{user_descr.inspect}'" unless user 
      user
    end

    # Return the user described by +user_descr+.
    #
    # Note: This is an unprivileged  operation as creating a user doesn't imply anything
    # else beyond opening a record.
    #
    # @param [Hash] properties of user
    # @return [User] The requested user
    # @raise [UnknownResourceException] if requested user cannot be found
    #
    def find_user(user_descr)
      unless user = OMF::SFA::Resource::User.first(user_descr)
        raise UnavailableResourceException.new "Unknown user '#{user_descr.inspect}'"
      end
      user
    end

    ### LEASES: creating, finding, and releasing leases

    # Return the lease described by +lease_descr+. Create if it doesn't exist.
    #
    # @param [Hash] lease_descr properties of lease
    # @param [Hash] lease oproperties like ":valid_from" and ":valid_until"
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OLease] The requested lease
    # @raise [UnknownResourceException] if requested lease cannot be created
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_or_create_lease(lease_descr, lease_oproperties, authorizer)
      debug "find_or_create_lease: '#{lease_descr.inspect}', '#{lease_oproperties.inspect}'"
      begin
        return find_lease(lease_descr, lease_oproperties, authorizer)
      rescue UnavailableResourceException
      end
      unless lease_oproperties.has_key?(:valid_from) && lease_oproperties.has_key?(:valid_until)
        raise UnavailablePropertiesException.new "Cannot create lease without ':valid_from' and 'valid_until' oproperties #{lease_oproperties.inspect}"
      end
      lease = create_resource(lease_descr, 'OLease', lease_oproperties, authorizer)
    end

    # Return the lease described by +lease_descr+.
    #
    # @param [Hash] properties of lease
    # @param [Hash] lease oproperties like ":valid_from" and ":valid_until"
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OLease] The requested lease
    # @raise [UnknownResourceException] if requested lease cannot be found
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def find_lease(lease_descr, lease_oproperties, authorizer)
      if lease_oproperties.empty?
        lease = OMF::SFA::Resource::OLease.first(lease_descr)
        authorizer.can_view_lease?(lease)
        return lease
      end
      leases = OMF::SFA::Resource::OLease.all(lease_descr)
      leases.each do |l|
        if (l[:valid_from] == lease_oproperties[:valid_from] && 
            l[:valid_until] == lease_oproperties[:valid_until])
          authorizer.can_view_lease?(l)
          return l
        end
      end
      raise UnavailableResourceException.new "Unknown lease '#{lease_descr.inspect}'"
    end

    # Return all leases of the specified account
    #
    # @param [OAccount] Account for which to find all associated leases
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OLease>] The account's leases (maybe empty)
    #
    def find_all_leases_for_account(account, authorizer)
      debug "find_all_leases_for_account: account:'#{account.inspect}' authorizer:'#{authorizer.inspect}'"
      leases = OMF::SFA::Resource::OLease.all(:account => account) 
      leases.map do |l|
        begin 
          authorizer.can_view_lease?(l)
          l
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Modify lease described by +lease_descr+ hash 
    #
    # @param [Hash] lease oproperties like ":valid_from" and ":valid_until"
    # @param [OLease] lease to modify
    # @param [Authorizer] Authorization context
    # @return [OLease] The requested lease
    #
    def modify_lease(lease_oproperties, lease, authorizer)    
      authorizer.can_modify_lease?(lease)
      lease.valid_from = lease_oproperties[:valid_from]
      lease.valid_until = lease_oproperties[:valid_until]
      lease.save
      lease
    end

    # cancel +lease+ 
    #
    # This implementation simply frees the lease record.
    #
    # @param [OLease] lease to release
    # @param [Authorizer] Authorization context
    #
    def release_lease(lease, authorizer)
      debug "release_lease: lease:'#{lease.inspect}' authorizer:'#{authorizer.inspect}'"
      authorizer.can_release_lease?(lease)

      lease.component_leases.each do |l|
        l.destroy # unlink the lease with the corresponding components
      end
      lease.status = :cancelled
    end

    #
    # Create or Modify leases through RSpecs
    #
    # When a uuid is provided, then the corresponding lease is modified. Otherwise a new
    # lease is created with the properties described in the RSpecs.
    #
    # @param [Nokogiri::XML::Node] RSpec fragment describing lease and its properties
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OLease] The requested lease
    # @raise [UnavailableResourceException] if no matching resource can be found or created
    # @raise [FormatException] if RSpec elements are not known
    #
    def update_lease_from_rspec(lease_el, authorizer)

      lease_properties = {:valid_from => Time.parse(lease_el[:valid_from]), :valid_until => Time.parse(lease_el[:valid_until])}

      unless lease_el[:uuid].nil?
        lease = find_lease({:uuid => lease_el[:uuid]}, {}, authorizer)
        raise UnavailableResourceException.new "Unknown lease uuid'#{lease_el[:uuid]}'" unless lease
        if lease.valid_from != lease_properties[:valid_from] || lease.valid_until != lease_properties[:valid_until]
          modify_lease(lease_properties, lease, authorizer)
        else
          lease
        end
      else
        lease_descr = {:name => authorizer.account.name}
        lease = find_or_create_lease(lease_descr, lease_properties, authorizer)
        lease
      end
    end

    # Update the leases described in +leases+. Any lease not already assigned to the
    # requesting account will be added. If +clean_state+ is true, the state of all described leases 
    # is set to the state described with all other properties set to their default values. Any leases
    # not mentioned are canceled. Returns the list
    # of leases requested or throw an error if ANY of the requested leases isn't available.
    # 
    # @param [Element] RSpec fragment describing leases and their properties
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Hash{String => OLease}] The leases requested
    # @raise [UnknownResourceException] if no matching lease can be found
    # @raise [FormatException] if RSpec elements are not known
    #        
    def update_leases_from_rspec(leases, authorizer)
      debug "update_leases_from_rspec: leases:'#{leases.inspect}' authorizer:'#{authorizer.inspect}'"
      unless leases.empty?
        leases = leases.collect do |l|
            update_lease_from_rspec(l, authorizer)
        end.compact 
      end
      leases
    end


    ### RESOURCES creating, finding, and releasing resources


    # Find a resource. If it doesn't exist throws +UnknownResourceException+ 
    # If it's not visible to requester throws +InsufficientPrivilegesException+
    #
    # @param [Hash, String, OResource] describing properties of the requested resource, or the 
    #   resource's UUID
    # @param [Boolean] If true, throw exception if not already assigned to requester
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    # @raise [FormatException] if the resource description is not String, UUID or OResource class/subclass
    # @raise [InsufficientPrivilegesException] if the resource is not visible to the requester
    #
    # @note This will assign the resource automatically to the requesting account
    #        
    def find_resource(resource_descr, authorizer)
      debug "find_resource: descr: '#{resource_descr.inspect}'"
      if resource_descr.kind_of? OMF::SFA::Resource::OResource
        resource = resource_descr
      elsif resource_descr.kind_of? Hash
        resource = OMF::SFA::Resource::OResource.first(resource_descr)
      elsif resource_descr.kind_of? String
        # assume to be UUID
        begin
          uuid = UUIDTools::UUID.parse(resource_descr)
          descr = {:uuid => uuid}
        rescue ArgumentError
          # doesn't seem to be a UUID, try it as a name - be aware of non-uniqueness
          descr = {:name => resource_descr}
        end
        resource = OMF::SFA::Resource::OResource.first(descr)
      else
        raise FormatException.new "Unknown resource description type '#{resource_descr.class}' (#{resource_descr})"
      end
      unless resource
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist"
      end
      authorizer.can_view_resource?(resource)
      resource
    end    

    # Find a resource which has been assigned to the authorizer's account. 
    # If it doesn't exist, or is not visible to requester
    # throws +UnknownResourceException+.
    #
    # @param [Hash, String] describing properties of the requested resource, or the 
    #   resource's UUID
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    #
    # @note This will assign the resource automatically to the requesting account
    #        
    def find_resource_for_account(resource_descr, authorizer)
      rdescr = resource_descr.dup
      rdescr[:account] = authorizer.account
      find_resource(rdescr, authorizer)
    end


    # Find all resources for a specific account.
    #
    # @param [OAccount] Account for which to find all associated resources
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OResource>] The resource requested
    #        
    def find_all_resources_for_account(account = _get_nil_account, authorizer)
      debug "find_all_resources_for_account: #{account.inspect}"
      res = OMF::SFA::Resource::OResource.all(:account => account)
      res.map do |r|
        begin
          authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find all components for a specific account.
    #
    # @param [OAccount] Account for which to find all associated component
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OComponent>] The component requested
    #        
    def find_all_components_for_account(account, authorizer)
      res = OMF::SFA::Resource::OComponent.all(:account => account)
      res.map do |r|
        begin
          authorizer.can_view_resource?(r)
          r
        rescue InsufficientPrivilegesException
          nil
        end
      end.compact
    end

    # Find all components
    #
    # @return [Array<OComponent>] The components requested
    #
    #def find_all_components
    #  res = OMF::SFA::Resource::OComponent.all
    #  res
    #end
            
    def find_or_create_resource(resource_descr, type_to_create, oproperties, authorizer)
      debug "find_or_create_resource: resource '#{resource_descr.inspect}' type: '#{type_to_create}'"
      unless resource_descr.is_a? Hash
        raise FormatException.new "Unknown resource description '#{resource_descr.inspect}'"
      end

      begin
        return find_resource(resource_descr, authorizer)
      rescue UnknownResourceException
      end
      create_resource(resource_descr, type_to_create, oproperties, authorizer)
    end

    # Create a resource
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Hash] A hash with all the OProperty values of the requested resource
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no resource can be created
    #
    def create_resource(resource_descr, type_to_create, oproperties, authorizer)
      authorizer.can_create_resource?(resource_descr, type_to_create)
      unless resource = @scheduler.create_resource(resource_descr, type_to_create, oproperties, authorizer)
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' cannot be created"
      end
      resource
    end

    # Find or create a resource for authorizer's account. If it doesn't exist, 
    # is already assigned to 
    # someone else, or cannot be created, throws +UnknownResourceException+.
    #
    # @param [Hash] describing properties of the requested resource
    # @param [String] Type to create if not already exist
    # @param [Hash] A hash with all the OProperty values of the requested resource
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    #        
    def find_or_create_resource_for_account(resource_descr, type_to_create, oproperties, authorizer)
      debug "find_or_create_resource_for_account: r_descr:'#{resource_descr}' type:'#{type_to_create}' authorizer:'#{authorizer.inspect}'"
      rdescr = resource_descr.dup
      rdescr[:account] = authorizer.account
      find_or_create_resource(rdescr, type_to_create, oproperties, authorizer)
    end

    # def _create_resource(resource_descr, type_to_create, authorizer)
    # # OK, let's check if a group was requested. They are cheap to make
    # #
    # # if type_to_create == 'group'
    # # copts = resource_descr.kind_of?(Hash) ? resource_descr : {}
    # # copts[:account] ||=  authorizer.account
    # # debug "_create_resource:create group: description '#{copts.keys.inspect}'"
    # # return create_group_resource(copts)
    # # end
    #       
    # # Let's see if this is a basic resource in which case we create a copy
    # #
    # # begin
    # # #resource_descr[:account] = _get_nil_account() 
    # # #r = find_resource(resource_descr, false, authorizer)
    # # return @scheduler.create_resource(resource_descr, authorizer)
    # # rescue UnknownResourceException
    # # end
    # unless @scheduler.create_resource(resource_descr, type_to_create, authorizer)
    # raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' cannot be created"    
    # end
    # end


    # Update the resources described in +resource_el+. Any resource not already assigned to the
    # requesting account will be added. If +clean_state+ is true, the state of all described resources 
    # is set to the state described with all other properties set to their default values. Any resources
    # not mentioned are released. Returns the list
    # of resources requested or throw an error if ANY of the requested resources isn't available.
    # 
    # Find or create a resource. If it doesn't exist, is already assigned to 
    # someone else, or cannot be created, throws +UnknownResourceException+.
    #
    # @param [Element] RSpec fragment describing resource and their properties
    # @param [Boolean] Set all properties not mentioned to their defaults
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    # @raise [FormatException] if RSpec elements are not known
    #        
    # @note Throws exception if a contained resource doesn't exist, but will not roll back any 
    # already performed modifications performed on other resources.
    #
    def update_resources_from_rspec(descr_el, clean_state, authorizer)
      debug "update_resources_from_rspec: descr_el:'#{descr_el.inspect}' clean_state:'#{clean_state}' authorizer:'#{authorizer.inspect}'"
      if descr_el.name.downcase == 'rspec'
        #if descr_el.namespaces.values.include?(OL_NAMESPACE)
        #  leases = descr_el.xpath('//ol:lease', 'ol' => OL_NAMESPACE)
        #  leases = update_leases_from_rspec(leases, clean_state, authorizer)
        #end

        ## If we don't remove the namespaces, we will have to search like this "xpath('//xmlns:node')"
        #descr_el.document.remove_namespaces! 

        resources = descr_el.xpath('//xmlns:node').collect do |el|
          #debug "create_resources_from_xml::EL: #{el.inspect}"
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            #if el[:lease_name].nil?
            #  update_resource_from_rspec(el, nil, clean_state, authorizer) 
            #else # This node has a lease
            #  lease = leases.find { |l| l[:name].eql?(el[:lease_name]) }
            leases = el.xpath('child::ol:lease', 'ol' => OL_NAMESPACE)
            leases = update_leases_from_rspec(leases, authorizer)
            update_resource_from_rspec(el, leases, clean_state, authorizer) 
            #end
          end
        end.compact
        # TODO: release the unused leases. The leases we have created but we never managed 
        # to attach them to a resource because the scheduler denied it.
        if clean_state
          # Now free any leases owned by this account but not contained in +leases+
          all_leases = Set.new
          leases = descr_el.xpath('//ol:lease', 'ol' => OL_NAMESPACE).collect do |l|
            update_leases_from_rspec(leases, authorizer)
          end.compact

          leases.each {|l| l.all_resources(all_leases)}
          unused = find_all_leases_for_account(authorizer.account, authorizer).to_set - all_leases
          unused.each do |u|
            release_lease(u, authorizer)
          end
          # Now free any resources owned by this account but not contained in +resources+
          rspec_resources = Set.new
          resources.each {|r| r.all_resources(rspec_resources)}
          all_components = find_all_components_for_account(authorizer.account, authorizer)
          unused = all_components.to_set - rspec_resources
          release_resources(unused, authorizer)
        end
        return resources
      else 
        raise FormatException.new "Unknown resources description root '#{descr_el.name}'"
      end
    end    

    # Update a single resource described in +resource_el+. The respective account is 
    # extracted from +opts+. Any mentioned resources not already available to the requesting account 
    # will be created. If +clean_state+ is set to true, all state of a resource not specifically described 
    # will be reset to it's default value. Returns the resource updated.
    # 
    def update_resource_from_rspec(resource_el, leases, clean_state, authorizer)
      if uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['idref'])
        uuid = UUIDTools::UUID.parse(uuid_attr.value)
        resource = find_resource({:uuid => uuid}, authorizer) # wouldn't know what to create
      elsif comp_id_attr = resource_el.attributes['component_id']
        comp_id = comp_id_attr.value
        comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
        #if uuid = comp_gurn.uuid
        #  resource_descr = {:uuid => uuid}
        #else
        #  resource_descr = {:name => comp_gurn.short_name}
        #end
        resource_descr = {:urn => comp_gurn}
        resource = find_or_create_resource_for_account(resource_descr, comp_gurn.type, {}, authorizer) 
        unless resource
          raise UnknownResourceException.new "Resource '#{resource_el.to_s}' is not available or doesn't exist"
        end
      elsif name_attr = resource_el.attributes['component_name']
        # the only resource we can find by a name attribute is a group
        # TODO: Not sure about the 'group' assumption
        name = name_attr.value
        resource = find_or_create_resource_for_account({:name => name}, 'unknown', {}, authorizer)
      else 
        raise FormatException.new "Unknown resource description '#{resource_el.attributes.inspect}"
      end

      leases.each do |l|
        #TODO: provide the scheduler with the resource and the lease to attach them according to its policy.
        # if the scheduler refuses to attach the lease to the resource, we should release both of them.
        @scheduler.lease_component(l, resource)
      end
      
      if resource.group?
        members = resource_el.children.collect do |el|
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            update_resource_from_rspec(el, clean_state, authorizer) 
          end
        end.compact
        debug "update_resource_from_rspec: Creating members '#{members}' for group '#{resource}'"

        if clean_state
          resource.members = members
        else
          resource.add_members(members)
        end
      else
        if clean_state
          # Set state to what's described in +resource_el+ ONLY
          resource.create_from_xml(resource_el, authorizer)
        else
          resource.update_from_xml(resource_el, authorizer)
        end
      end
      resource.save
      resource
    end

    # Release an array of resources. 
    #
    # @param [Array<OResource>] Resources to release
    # @param [Authorizer] Authorization context
    def release_resources(resources, authorizer)
      resources.each do |r|
        release_resource(r, authorizer)
      end
    end    

    # Release 'resource'. 
    #
    # This implementation simply frees the resource record.
    #
    # @param [OResource] Resource to release
    # @param [Authorizer] Authorization context
    #
    def release_resource(resource, authorizer)
      authorizer.can_release_resource?(resource)
      @scheduler.release_resource(resource, authorizer)
      #resource.remove_from_all_groups

      # if r.kind_of? OMF::SFA::Resource::CompGroup
      #   # groups don't go back in the pool, they are created per account
      #   r.destroy
      # else 
      #   r.account = def_account
      #   r.save
      # end
      #resource.destroy
    end

    #
    # This method finds all the components of the specific account and
    # detaches them.
    #
    # @param [OAccount] Account who owns the components
    # @param [Authorizer] Authorization context
    #
    def release_all_components_for_account(account, authorizer)
      components = find_all_components_for_account(account, authorizer)
      release_resources(components, authorizer)
    end


    # This methods deletes components, or more broadly defined, removes them
    # from a slice. 
    #
    # Currently, we simply transfer components to the +default_sliver+
    #    
    # def delete_resource(resource_descr, authorizer)
    # resource = find_resource(resource_descr, false, authorizer)
    # if resource.kind_of? OMF::SFA::Resource::OComponent
    # resource.account = _get_nil_account
    # resource.remove_from_all_groups
    # resource.save
    # else
    # resource.destroy
    # end
    # end      

    # This methods deletes components, or more broadly defined, removes them
    # from a slice. 
    #
    # Currently, we simply transfer components to the +default_sliver+
    #    
    # def delete_resource(resource_descr, opts)
    # resource = find_resource(resource_descr, false, opts)
    # if resource.kind_of? OMF::SFA::Resource::OComponent
    # resource.account = _get_nil_account
    # resource.remove_from_all_groups
    # resource.save
    # else
    # resource.destroy
    # end
    # end      

    # Return the account identified by 'uuid'.
    # 
    # @param [String, UUID] UUID of account
    # @return [OAccount]
    #
    # def get_account(uuid, authorizer)
    # unless account = OAccount.first(:uuid => uuid)
    # raise UnknownAccountException.new "Unknown account with uuid '#{uuid}'"
    # end
    # if account.closed?
    # raise ClosedAccountException.new 
    # end
    # end

    # Return a list of resources for a particular +account+. If
    # +account+ is null, return all the resources available at this
    # AM.
    # 
    # @param [OAccount] Account for which to find resources
    # @param [Authorizer] Authoization context
    #
    #def get_resources_for_account(account, authorizer)
    #  OMF::SFA::Resource::OComponent.all(:account => account)
    #end


    def _get_nil_account()
      @scheduler.get_nil_account()
    end

  end # class

end # OMF::SFA::AM
