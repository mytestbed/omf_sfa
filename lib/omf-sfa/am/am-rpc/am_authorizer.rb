require 'omf_common/lobject'
require 'omf-sfa/am/default_authorizer'
require 'omf-sfa/am/user_credential'
require 'omf-sfa/am/privilege_credential'

module OMF::SFA::AM::RPC

  include OMF::Common

  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class AMAuthorizer < OMF::SFA::AM::DefaultAuthorizer

    # @!attribute [r] account
    #        @return [OAccount] The account associated with this instance
    attr_reader :account

    # @!attribute [r] project
    #        @return [OProject] The project associated with this account
    attr_reader :project

    # @!attribute [r] user
    #        @return [User] The user associated with this membership
    attr_reader :user


    # @!attribute [r] certificate
    #        @return [Hash] The certificate associated with this caller
#    attr_reader :certificate


    # Create an instance from the information
    # provided by the rack's 'req' object.
    #
    # @param [Rack::Request] Request provided by the Rack API
    # @param [AbstractAmManager#get_account] AM Manager for retrieving AM context
    #
    def self.create_for_web_request(account_urn, credentials, request, am_manager)

      begin
        raise "Missing peer cert" unless cert_s = request.env['rack.peer_cert']
        peer = OMF::SFA::AM::UserCredential.unmarshall(cert_s)
      end
      debug "Requester: #{peer.subject} :: #{peer.user_urn}"

      unless peer.valid_at?     
        OMF::SFA::AM::InsufficientPrivilegesException.new "The certificate has expired or not valid yet. Check the dates."
      end
      user = am_manager.find_or_create_user({:uuid => peer.user_uuid, :urn => peer.user_urn})

      creds = credentials.map do |cs|
        cs = OMF::SFA::AM::PrivilegeCredential.unmarshall(cs)
        cs.tap do |c|
          unless c.valid_at?
            OMF::SFA::AM::InsufficientPrivilegesException.new "The credentials have expired or not valid yet. Check the dates."
          end
        end
      end

            
      self.new(account_urn, peer, creds, am_manager)
    end


    ##### ACCOUNT

    def can_renew_account?(account, expiration_time)
      debug "Check permission 'can_renew_account?' (#{account == @account}, #{@permissions[:can_renew_account?]}, #{@user_cred.valid_at?(expiration_time)})"
      unless account == @account && 
          @permissions[:can_renew_account?] && 
          @user_cred.valid_at?(expiration_time) # not sure if this is the right check
        raise OMF::SFA::AM::InsufficientPrivilegesException.new("Can't renew account after the expiration of the credentials")
      end
    end
        
    ##### RESOURCE
    
    def can_release_resource?(resource)
      unless resource.account == @account && @permissions[:can_release_resource?]
        raise OMF::SFA::AM::InsufficientPrivilegesException.new      
      end
    end
    
    protected

    def initialize(account_urn, user_cert, credentials, am_manager)
      super()
      
      @user_cert = user_cert
      
      # NOTE: We only look at the first cred
      credential = credentials[0]
      debug "cred: #{credential.inspect}"
      unless (user_cert.user_urn == credential.user_urn)
        raise OMF::SFA::AM::InsufficientPrivilegesException.new "User urn mismatch in certificate and credentials. cert:'#{user_cert.user_urn}' cred:'#{credential.user_urn}'" 
      end
      
      @user_cred = credential
      
      
      if credential.type == 'slice'
        @permissions[:can_create_account?] = credential.privilege?('control')
        @permissions[:can_view_account?] = credential.privilege?('info')
        @permissions[:can_renew_account?] = credential.privilege?('refresh')
        @permissions[:can_close_account?] = credential.privilege?('control')
      end

      @permissions[:can_create_resource?] = credential.privilege?('refresh')
      @permissions[:can_view_resource?] = credential.privilege?('info')
      @permissions[:can_release_resource?] = credential.privilege?('refresh')

      @permissions[:can_view_lease?] = credential.privilege?('info')
      @permissions[:can_modify_lease?] = credential.privilege?('refresh')
      @permissions[:can_release_lease?] = credential.privilege?('refresh')
      
      debug "Have permission '#{@permissions.keys.inspect}'"

      unless account_urn.nil?
        unless account_urn.eql?(credential.target_urn)
          raise OMF::SFA::AM::InsufficientPrivilegesException.new "Slice urn mismatch in XML call and credentials"
        end 

        @account = am_manager.find_or_create_account({:urn => account_urn}, self)
        @account.valid_until = @user_cred.valid_until
        if @account.closed?
          if @permissions[:can_create_account?]
            @account.closed_at = nil
          else
            raise OMF::SFA::AM::InsufficientPrivilegesException.new("You don't have the privilege to enable a closed account")
          end
        end
        # XXX: decide where/when to create the Project. Right now we are creating it along with the account in the above method
        @project = @account.project
      end
      
    end

  end
end
