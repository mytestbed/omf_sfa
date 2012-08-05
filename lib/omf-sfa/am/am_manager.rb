
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

  class MissingImplementationException < Exception; end
    
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
    
    ### MANAGMENT INTERFACE: adding and removing from the AM's control
    
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
    
    ### RESOURCES creating, finding, and releasing resources

    
    # Find a resource. If it doesn't exist, or is not visible to requester
    # throws +UnknownResourceException+.
    #
    # @param [Hash, String] describing properties of the requested resource, or the 
    #   resource's UUID
    # @param [Boolean] If true, throw exception if not already assigned to requester
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    #
    # @note This will assign the resource automatically to the requesting account
    #        
    def find_resource(resource_descr, requester_only, authorizer)
      #debug "find_resource: descr: '#{resource_descr.inspect}'"
      if resource_descr.kind_of? OMF::SFA::Resource::OResource
        resource = resource_descr
      elsif resource_descr.kind_of? Hash
        if requester_only
          resource_descr[:account] = authorizer.account
        end
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
        if requester_only
          descr[:account] = authorizer.account
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
    
    # Find all resources for a specific account.
    #
    # @param [OAccount] Account for which to find all associated resources
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OResource>] The resource requested
    #        
    def find_all_resources_for_account(account, authorizer)
      #debug "find_all_resources_for_account: #{account.inspect}"
      res = OMF::SFA::Resource::OResource.all(:account => account)
      res
    end

    # Find or create a resource. If it doesn't exist, is already assigned to 
    # someone else, or cannot be created, throws +UnknownResourceException+.
    #
    # @param [Hash] describing properties of the requested resource
    # @param [String] Type to create if not already exist
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource requested
    # @raise [UnknownResourceException] if no matching resource can be found
    #        
    def find_or_create_resource(resource_descr, type_to_create, authorizer)
      debug "find_or_create_resource: resource '#{resource_descr.inspect}' type: '#{type_to_create}'"
      unless resource_descr.is_a? Hash
        error "Unknown resource description '#{resource_descr.inspect}'"
        return nil
      end
      
      account = authorizer.account
      begin
        resource_descr[:account] = account 
        return find_resource(resource_descr, false, authorizer)
      rescue UnknownResourceException
      end
      #_create_resource(resource_descr, type_to_create, authorizer)
      unless resource = @scheduler.create_resource(resource_descr, type_to_create, authorizer)
        raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' cannot be created"    
      end
      resource
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
      if descr_el.name.downcase == 'rspec'
        resources = descr_el.children.collect do |el|
          #debug "create_resources_from_xml::EL: #{el.inspect}"
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            update_resource_from_rspec(el, clean_state, authorizer) 
          end
        end.compact
        if clean_state
          # Now free any resources owned by this account but not contained in +resources+
          all_resources = Set.new
          resources.each {|r| r.all_resources(all_resources)}
          unused = find_all_resources_for_account(authorizer.account, authorizer) - all_resources
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
    def update_resource_from_rspec(resource_el, clean_state, authorizer)
      resource = nil 
      if uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['idref'])
        uuid = UUIDTools::UUID.parse(uuid_attr.value)
        resource = find_resource({:uuid => uuid}, false, authorizer) # wouldn't know what to create
      elsif comp_id_attr = resource_el.attributes['component_id']
        comp_id = comp_id_attr.value
        comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
        #begin
          if uuid = comp_gurn.uuid
            resource = find_or_create_resource({:uuid => uuid}, comp_gurn.type, authorizer)
          else
            resource = find_or_create_resource({:name => comp_gurn.short_name}, comp_gurn.type, authorizer)
          end
        # rescue UnknownResourceException => ex
          # # let's try the less descriptive 'component_name'
          # if comp_name_attr = resource_el.attributes['component_name']
            # comp_name = comp_name_attr.value
            # resource = find_or_create_resource({:name => comp_name}, comp_gurn.type, authorizer)
          # else
            # raise ex # raise original exception
          # end
        # end
      elsif name_attr = resource_el.attributes['component_name']
        # the only resource we can find by a name attribute is a group
        # TODO: Not sure about the 'group' assumption
        name = name_attr.value
        resource = find_or_create_resource({:name => name}, 'group', authorizer)
      else 
        raise FormatException.new "Unknown resource description '#{resource_el.attributes.inspect}"
      end
      unless resource
        raise UnknownResourceException.new "Resource '#{resource_el.to_s}' is not available or doesn't exist"
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
      resource.remove_from_all_groups
      
      # if r.kind_of? OMF::SFA::Resource::CompGroup
      #   # groups don't go back in the pool, they are created per account
      #   r.destroy
      # else 
      #   r.account = def_account
      #   r.save
      # end
      resource.destroy
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
    # def get_resources_for_account(account, authorizer)
      # OMF::SFA::Resource::OComponent.all(:account => account)
    # end
#     
#     
    def _get_nil_account()
      @scheduler.get_nil_account()
    end
              
  end # class
    
end # OMF::SFA::AM
