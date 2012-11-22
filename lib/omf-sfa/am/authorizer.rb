require 'omf_common/lobject'

module OMF::SFA::AM

  include OMF::Common

  class InsufficientPrivilegesException < AMManagerException; end

  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class Authorizer < LObject

    # @!attribute [r] account
    #	@return [OAccount] The account associated with this instance
    attr_reader :account

    # @!attribute [r] project
    #	@return [OProject] The project associated with this account
    attr_reader :project

    # @!attribute [r] user
    #	@return [User] The user associated with this membership
    attr_reader :user

    # @!attribute [r] privileges
    #	@return [Hash] The privileges associated with this user
    attr_reader :privileges

    # @!attribute [r] certificate
    #	@return [Hash] The certificate associated with this caller
    attr_reader :certificate


    # Create an instance from the information
    # provided by the rack's 'req' object.
    #
    # @param [Rack::Request] Request provided by the Rack API
    # @param [AbstractAmManager#get_account] AM Manager for retrieving AM context
    #
    def self.create_for_web_request(request, am_manager)

      begin
	raise "Missing peer cert" unless cert_s = request.env['rack.peer_cert']
	peer = OMF::SFA::AM::UserCredential.unmarshall(cert_s)
      end

      debug "Requester: #{peer.subject} :: #{peer.user_urn}"

      if peer.cert.not_before > Time.now || peer.cert.not_after < Time.now      
        raise "The certificate has expired or not valid yet. Check the dates."
      end

      #user_name = peer.user_urn.split('+').last

      # XXX: bootstraping problem here. We have to create a user but we have not created the authorizer nor we have the credentials of the caller. 
      user = am_manager.find_or_create_user({:uuid => peer.user_uuid, :urn => peer.user_urn})
      self.new(user, peer.cert)
    end

    # Throws exception if credentials XML encoded in +cred_string_a+
    # are *not* sufficient for _action_
    #
    def check_credentials(slice_urn, cred_string_a, am_manager)
      credentials = unmarshall_credentials(cred_string_a)

      #@privileges = credentials.privileges

      #puts "slice urn: #{credentials.slice_urn}"
      #puts "user urn: #{credentials.user_urn}"
      #puts "signer urn: #{credentials.signer_urn}"


      # GENI API Credentials
      # The privileges are the rights that are assigned to the owner
      # of the credential on the target resource. Different slice
      # authorities use different permission names, but they have
      # similar semantic meaning.  If and only if a privilege can
      # be delegated, then that means the owner of the credential
      # can delegate that permission to another entity. 
      # Currently, the only credentials used in the GENI API are
      # slice credentials and user credentials.  Privileges have not
      # yet been agreed upon between the control frameworks.  
      # Currently, SFA assigns ['refresh', 'resolve', and 'info'] 
      # rights to user credentials.    
      # Slice credentials have "slice" rights. ProtoGENI defaults 
      # to the "*" privilege which means that the owner has rights 
      # to all methods associated with that credential type 
      # (user or slice). 
      # See https://www.protogeni.net/trac/protogeni/wiki/ReferenceImplementationPrivileges for more information on ProtoGENI privileges.

      raise "User urn mismatch in certificate and credentials" unless @user.urn.eql?(credentials.user_urn)

      # FIXME: target_urn is not always the slice. 
      raise "Slice urn mismatch in XML call and credentials" unless slice_urn.nil? || slice_urn.eql?(credentials.target_urn)

      # XXX: as administrators we must be able to create accounts without authorizer. The other approach is to have already an authorizer for nil account with full privileges...
      unless slice_urn.nil?
	account_descr = { :urn => slice_urn }
	@account = am_manager.find_or_create_account(account_descr, self)
	# XXX: decide where/when to create the Project. Right now we are creating it along with the account in the above method
	@project = @account.project
      end
    end

    def unmarshall_credentials(cred_string_a)
      credentials = OMF::SFA::AM::PrivilegeCredential.unmarshall(cred_string_a)
      # urn:publicid:IDN+topdomain:subdomain+slice+test
      cred_type = credentials.target_urn.split('+')[2] # it should be one of "slice" or "user"

      @permissions = {}

      if cred_type.eql?('slice')
	@permissions['can_create_account'] = true if credentials.privileges.has_key?('control')
	@permissions['can_view_account'] = true if credentials.privileges.has_key?('info')
	@permissions['can_renew_account'] = true if credentials.privileges.has_key?('refresh')
	@permissions['can_close_account'] = true if credentials.privileges.has_key?('control')
      end

      @permissions['can_create_resource'] = true if credentials.privileges.has_key?('refresh')
      @permissions['can_view_resource'] = true if credentials.privileges.has_key?('info')
      @permissions['can_release_resource'] = true if credentials.privileges.has_key?('refresh')

      @permissions['can_create_lease'] = true if credentials.privileges.has_key?('refresh')
      @permissions['can_view_lease'] = true if credentials.privileges.has_key?('info')
      @permissions['can_modify_lease'] = true if credentials.privileges.has_key?('refresh')
      @permissions['can_release_lease'] = true if credentials.privileges.has_key?('refresh')

      #puts @permissions


      #begin
      #  unless cert_s = @request.env['rack.peer_cert']
      #    raise "Missing peer cert"
      #  end
      #  peer_cert = OMF::SFA::AM::UserCredential.unmarshall(cert_s)
      #end

      #debug "Requester: #{peer_cert.subject} :: #{peer_cert.user_urn}"

      #TODO: why are we handling multiple credential files here?
      #begin
      #  credentials = cred_string_a.map do |cd|
      #    #debug "Credential: ", cd
      #    OMF::SFA::AM::PrivilegeCredential.unmarshall(cd)
      #  end
      #rescue Exception => ex
      #  warn "Error while parsing credentials #{ex}"
      #  debug "\t#{ex.backtrace.join("\n\t")}"
      #end
      #debug "Credentials::: #{credentials.inspect}"
      credentials
    end

    ##### ACCOUNT

    def can_create_account?
      unless @permissions['can_create_account']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_view_account?(account)
      unless @permissions['can_view_account']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_renew_account?(account, expiration_time)
      unless @permissions['can_renew_account'] && expiration_time <= @certificate.not_after
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_close_account?(account)
      unless @permissions['can_close_account']
        raise InsufficientPrivilegesException.new
      end
    end
    
    ##### RESOURCE

    def can_create_resource?(resource_descr, type)
      unless @permissions['can_create_resource']
        raise InsufficientPrivilegesException.new
      end
    end

    def can_view_resource?(resource)
      unless @permissions['can_view_resource']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_release_resource?(resource)
      unless resource.account == @account && @permissions['can_release_resource']
        raise InsufficientPrivilegesException.new      
      end
    end
    
    ##### LEASE

    def can_create_lease?(lease)
      unless @permissions['can_create_lease']
	raise InsufficientPrivilegesException.new
      end
    end

    def can_view_lease?(lease)
      unless @permissions['can_view_lease']
	raise InsufficientPrivilegesException.new
      end
    end
    
    def can_modify_lease?(lease)
      unless @permissions['can_modify_lease']
	raise InsufficientPrivilegesException.new
      end
    end
    
    def can_release_lease?(lease)
      unless @permissions['can_release_lease']
	raise InsufficientPrivilegesException.new
      end
    end

    protected

    #def initialize(account, permissions = {})
    #  @account = account
    #  @permissions = permission
    #end

    #def initialize(account, am_manager)
    #  @am_manager = am_manager 
    #  @account = account
    #end

    def initialize(user, certificate)
      @user = user
      @certificate = certificate
    end

  end
end
