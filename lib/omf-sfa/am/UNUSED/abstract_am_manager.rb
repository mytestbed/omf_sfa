
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
  
  # Holds the necessary information to make authorization decisions
  #
  Struct.new('AuthorizationContext', :account, :user)
  
  # The manager is where all the AM related policies and 
  # resource management is concentrated. Testbeds with their own 
  # ways of dealing with resources and components should only 
  # need to extend this class.
  #
  class AbstractManager < OMF::Common::LObject
    
    # # Register a resource to be managed by this AM.
    # # 
    # def manage_resource(resource)
      # raise MissingImplementationException.new
    # end
# 
    # # Register an array of resources to be managed by this AM.
    # # 
    # def manage_resources(resources)
      # MISS
    # end
    

    # Release resources currently used by an account into the global pool
    #
    # @param [Array<OResource>] Resources to release
    # @param [Authorizer] Authorization context
    def free_resources(resources, authorizer)
      raise MissingImplementationException.new
    end    
    
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
      raise MissingImplementationException.new
    end    
    
    # Find all resources for a specific account.
    #
    # @param [OAccount] Account for which to find all associated resources
    # @param [Authorizer] Defines context for authorization decisions
    # @return [Array<OResource>] The resource requested
    #        
    def find_all_resources_for_account(account, authorizer)
      raise MissingImplementationException.new
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
      
      # OK, let's check if a group was requested. They are cheap to make
      #
      if type_to_create == 'group'
        copts = resource_descr.kind_of?(Hash) ? resource_descr : {}
        copts[:account] ||=  account
        debug "find_or_create_resource:create group: authorizer '#{copts.keys.inspect}'"
        #return OMF::SFA::Resource::CompGroup.create(copts)
        return create_group_resource(copts)
      end
      
      # Let's see if this is a basic resource in which case we create a copy
      #
      begin
        resource_descr[:account] = get_default_account() 
        r = find_resource(resource_descr, false, authorizer)
        return virtualize_resource(r, resource_descr, authorizer)
      rescue UnknownResourceException
      end

      raise UnknownResourceException.new "Resource '#{resource_descr.inspect}' is not available or doesn't exist"      
    end
    
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
    def update_resources_from_xml(descr_el, clean_state = false, authorizer = {})
      if descr_el.name.downcase == 'rspec'
        resources = descr_el.children.collect do |el|
          #debug "create_resources_from_xml::EL: #{el.inspect}"
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            update_sfa_resource_from_xml(el, clean_state, authorizer) 
          end
        end.compact
        if clean_state
          # Now free any resources owned by this account but not contained in +resources+
          all_resources = Set.new
          resources.each {|r| r.all_resources(all_resources)}
          unused = find_all_resources_for_account(get_requester_account(opts), authorizer) - all_resources
          free_resources(unused, authorizer)
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
    def update_sfa_resource_from_xml(resource_el, clean_state, authorizer = {})
      if comp_id_attr = resource_el.attributes['component_id']
        comp_id = comp_id_attr.value
        comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
        begin 
          resource = find_or_create_resource({:name => comp_gurn.short_name}, comp_gurn.type, authorizer)
        rescue UnknownResourceException => ex
          # let's try the less descriptive 'component_name'
          if comp_name_attr = resource_el.attributes['component_name']
            comp_name = comp_name_attr.value
            resource = find_or_create_resource({:name => comp_name}, comp_gurn.type, authorizer)
          else
            raise ex # raise original exception
          end
        end
      elsif name_attr = resource_el.attributes['name']
        # the only resource we can find by a name attribute is a group
        name = name_attr.value
        account = get_requester_account(opts)
        resource = find_or_create_resource({:name => name, :account => account}, 'group', authorizer)
      elsif uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['idref'])
        uuid = UUIDTools::UUID.parse(uuid_attr.value)
        resource = find_resource({:uuid => uuid}, false, authorizer) # wouldn't know what to create
      else 
        raise FormatException.new "Unknown resource description '#{resource_el.attributes.inspect}"
      end
      unless resource
        raise UnknownResourceException.new "Resource '#{resource_el.to_s}' is not available or doesn't exist"
      end
      
      #if resource.kind_of? OMF::SFA::Resource::CompGroup
      if resource.group?
        members = resource_el.children.collect do |el|
          if el.kind_of?(Nokogiri::XML::Element)
            # ignore any text elements
            update_sfa_resource_from_xml(el, clean_state, authorizer) 
          end
        end.compact
        debug "update_sfa_resource_from_xml: Creating members '#{members}' for group '#{resource}'"

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
    
    

    # This methods deletes components, or more broadly defined, removes them
    # from a slice. 
    #
    # Currently, we simply transfer components to the +default_sliver+
    #    
    def delete_resource(resource_descr, authorizer)
      MISS
    end      
          
    # # Returns the +Account+ instance of the requester. It should either be
    # # stored in +opts+ under :req/account_id, or there should be a 
    # # :requester_account
    # # 
    # def get_requester_account(opts)
    #   unless account = opts[:requester_account] || opts[:account]
    #     if account_id = (opts[:req] || {})[:account_id]
    #       if uuid_m = account_id.match(/^urn:uuid:(.*)/)
    #         #uuid = UUIDTools::UUID.parse(uuid_m[1])
    #         uuid = uuid_m[1]
    #         unless account = get_account(uuid)
    #           raise UnknownAccountException.new "Unknown account with uuid '#{uuid}'"
    #         end
    #         if account.closed?
    #           raise ClosedAccountException.new 
    #         end
    #       else
    #         raise FormatException.new "Unknown account format '#{account_id}'"
    #       end
    #     else
    #       account = get_default_account()
    #     end
    #     opts[:requester_account] = account
    #   end
    #   account        
    # end
    
    # Return the account identified by 'uuid'.
    # 
    # @param [String, UUID] UUID of account
    # @return [OAccount]
    def get_account(uuid)
      MISS
    end
    
    # Return the account which everything is going to be charged if we don't have 
    # a 'real' account. Essentially the AM's own account, keeping track of
    # 'lost revenue'.
    #
    def get_default_account()
      MISS
    end
    
    # Return a list of resources for a particular +slice_urn+. If
    # +slice_urn+ is null, return all the resources available at this
    # AM. If +ensure_account_active+ is true, throw +UnavailableResourceException+
    # if account is closed.
    #
    def get_resources_for_account(account_urn, ensure_account_active = true)
      account = account_urn ? find_account(:urn => account_urn) : get_default_account()
      if ensure_account_active && account.closed?
        raise UnavailableResourceException.new "Account '#{account_urn}' closed"
      end
      resources = _get_resources_for_account(account)
      resources
    end
    
    def _get_resources_for_account(account)
      #OMF::SFA::Resource::OComponent.all(:account => account)
      MISS
    end
    
    # Return the account described by +account_descr+. Create if it doesn't exist.
    #
    def find_or_create_account(account_descr)
      debug "find_or_create_account: '#{account_descr.inspect}'"
      MISS
    end
    
    # Return all accounts visible to the requesting user
    #
    def find_all_accounts(authorizer)
      # OMF::SFA::Resource::OAccount.all() - get_default_account()
      MISS
    end
    
    # Return the account described by +account_descr+.
    #
    def find_account(account_descr)
      MISS
    end
    
    # Return the account described by +account_descr+. Create if it doesn't exist.
    #
    def find_active_account(account_descr)
      account = find_account(account_descr)
      if account.closed?
        raise UnavailableResourceException.new "Account '#{account.inspect}' is closed"
      end
      account
    end
    

    # Renew account described by +account+ hash until +expiration_time+
    #
    def renew_account_until(account, expiration_time)    
      # account = find_active_account(account)
      # account.valid_until = expiration_time
      MISS
    end
    
    # Delete account described by +account+ hash.
    #
    # Make sure that all associated resources are freed as well
    #
    def delete_account(account_descr)
      MISS
    end
        
  end # AbstractManager
    
end # OMF::SFA::AM
