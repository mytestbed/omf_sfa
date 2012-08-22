require 'omf_common/lobject'

module OMF::SFA::AM

  include OMF::Common
  
  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class Authorizer < LObject
   
    # Create an instance from the information
    # provided by the rack's 'req' object.
    #
    # @param [Rack::Request] Request provided by the Rack API
    # @param [AbstractAmManager#get_account] AM Manager for retrieving AM context
    #
    def self.create_for_web_request(req, am_manager)
      if account_id = req[:account_id]
        if uuid_m = account_id.match(/^urn:uuid:(.*)/)
          #uuid = UUIDTools::UUID.parse(uuid_m[1])
          uuid = uuid_m[1]
          unless account = am_manager.get_account(uuid)
            raise UnknownAccountException.new "Unknown account with uuid '#{uuid}'"
          end
          if account.closed?
            raise ClosedAccountException.new 
          end
        else
          raise FormatException.new "Unknown account format '#{account_id}'"
        end
      else
        account = am_manager._get_nil_account()
      end
      user = nil # TODO: Fix me
      self.new(account, user, am_manager)        
    end

    # Check if 'resource' can be released.
    #
    # @param [OResource] Resource to be released
    # @raise [InsufficientPrivilegesException] if permission is not granted
    #
    def can_release_resource?(resource)
      unless resource.account == @account
        throw InsufficientPrivilegesException.new "Not authorized to release resource '#{resource.uuid}'"
      end
    end

    # @return [OAccount] The account associated with this instance
    attr_reader :account
    
    protected
    
    def initialize(account, user, am_manager)
      @account = account
      @user = user
      @am_manager = am_manager 
    end
    
  end
end
