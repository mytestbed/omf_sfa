require 'omf_common/lobject'

module OMF::SFA::AM

  include OMF::Common

  class InsufficientPrivilegesException < AMManagerException; end

  # This class implements the decision logic for determining
  # access of a user in a specific context to specific functionality
  # in the AM
  #
  class Authorizer < LObject

    # @return [OAccount] The account associated with this instance
    attr_reader :account


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

      #OPTIMIZE: In my view, this is a bootstrapping problem. Should we keep it this way?
      user_name = peer.user_urn.split('+').last
      default_account = am_manager._get_nil_account
      account = am_manager.find_or_create_account({:uuid => peer.user_uuid, :urn => peer.user_urn, :name => user_name}, self.new(default_account, am_manager))
      #account = OAccount.first_or_create({:uuid => peer_cert.uuid}, {:urn => peer_cert.urn}, {:valid_until => peer_cert.not_after})
      account.valid_until = peer.cert.not_after
      account.save

      puts account.inspect
      self.new(account, am_manager)

      #if account_id = req.env[:account_id]
      #  if uuid_m = account_id.match(/^urn:uuid:(.*)/)
      #    #uuid = UUIDTools::UUID.parse(uuid_m[1])
      #    uuid = uuid_m[1]
      #    unless account = am_manager.get_account(uuid)
      #      raise UnknownAccountException.new "Unknown account with uuid '#{uuid}'"
      #    end
      #    if account.closed?
      #      raise ClosedAccountException.new 
      #    end
      #  else
      #    raise FormatException.new "Unknown account format '#{account_id}'"
      #  end
      #else
      #  account = am_manager._get_nil_account()
      #end
      #user = nil # TODO: Fix me
      #self.new(account, user, am_manager)        
    end

    # Throws exception if credentials XML encoded in +cred_string_a+
    # are *not* sufficient for _action_
    #
    def check_credentials(action, slice_urn, cred_string_a)
      credentials = unmarshall_credentials(cred_string_a)

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

      raise "User urn mismatch in certificate and credentials" unless account.urn.eql?(credentials.user_urn)

      raise "Slice urn mismatch in XML call and credentials" unless slice_urn.nil? || slice_urn.eql?(credentials.slice_urn)

      case action
      when :ListResources 
	unless slice_urn.nil? || credentials.privileges["info"]
          raise InsufficientPrivilegesException.new "Insufficient credentials"
	end
      when :CreateSliver
      else
	raise "Uknown Method Called"
      end

      credentials
    end

    def unmarshall_credentials(cred_string_a)
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
      #credentials
      OMF::SFA::AM::PrivilegeCredential.unmarshall(cred_string_a)
    end

    ##### ACCOUNT

    def can_create_account?
      return true
      unless @permissions['can_create_account']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_view_account?(account)
      return true
      unless @permissions['can_view_account']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_renew_account?(account, expiration_time)
      unless @permissions['can_renew_account']
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
      return true
      unless @permissions['can_create_resource']
        raise InsufficientPrivilegesException.new
      end
    end

    def can_view_resource?(resource)
      return true
      unless @permissions['can_view_resource']
        raise InsufficientPrivilegesException.new
      end
    end
    
    def can_release_resource?(resource)
      unless resource.account == @account && @permissions['can_release_resource']
        raise InsufficientPrivilegesException.new      
      end
    end
    
    protected

    #def initialize(account, permissions = {})
    #  @account = account
    #  @permissions = permission
    #end

    def initialize(account, am_manager)
      @am_manager = am_manager 
      @account = account
    end

  end
end
