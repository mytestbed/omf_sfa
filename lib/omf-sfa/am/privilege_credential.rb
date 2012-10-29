require 'omf-sfa/am/credential'

module OMF::SFA::AM
  class PrivilegeCredential < Credential

    attr_reader :privileges
    
    def self.verify_type(type)
      raise "Expected type 'privilege' but got '#{type}'" unless type == 'privilege'
    end
    
    def slice_urn
      target_urn
    end
    
    def user_urn
      owner_urn
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
