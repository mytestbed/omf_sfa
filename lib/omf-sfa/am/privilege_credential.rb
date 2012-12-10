require 'omf-sfa/am/credential'

module OMF::SFA::AM
  
  # Throws exception if credentials XML encoded in +cred_string_a+
  # are *not* sufficient for _action_
  #
  # GENI API Credentials
  #
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
  # See https://www.protogeni.net/trac/protogeni/wiki/ReferenceImplementationPrivileges 
  # for more information on ProtoGENI privileges.
  #
  class PrivilegeCredential < Credential
    #attr_reader :privileges
    
    def self.verify_type(type)
      raise "Expected type 'privilege' but got '#{type}'" unless type == 'privilege'
    end
    
    def privilege?(pname)
      @privileges.has_key?(pname)
    end
    
    def user_urn
      owner_urn
    end
    
    def type
      # urn:publicid:IDN+topdomain:subdomain+slice+test
      target_urn.split('+')[2] # it should be one of "slice" or "user"
    end

    
    # Create a credential described in +description_doc+ .
    #
    def initialize(description_doc, signer_urn)
      super
      # @see http://groups.geni.net/geni/wiki/GeniApiCredentials
      # <privileges>
        # <privilege><name>refresh</name><can_delegate>true</can_delegate></privilege>
        # <privilege><name>embed</name><can_delegate>true</can_delegate></privilege>
        # <privilege><name>bind</name><can_delegate>true</can_delegate></privilege>
        # <privilege><name>control</name><can_delegate>true</can_delegate></privilege>
        # <privilege><name>info</name><can_delegate>true</can_delegate></privilege>
      # </privileges>
      unless el = description_doc.xpath('//credential/privileges')[0]
        raise "Missing element 'privileges' in credential"
      end
      @privileges = {}
      el.children.each do |pel|
        p = {} 
        pel.children.each do |cel|
          p[cel.name.to_sym] = cel.content
        end
	      # example: @privileges={"refresh"=>{:can_delegate=>"true"}, "resolve"=>{:can_delegate=>"true"}, "info"=>{:can_delegate=>"true"}}
        @privileges[p.delete(:name)] = p 
      end
    end

  end # PrivilegeCredential                     
end # OMF::SFA::AM
