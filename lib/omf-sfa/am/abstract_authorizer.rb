
require 'omf_common/lobject'
require 'omf-sfa/resource'

module OMF::SFA::AM

  class InsufficientPrivilegesException < AMManagerException; end  

  # This class implements an authorizer which 
  # allows nothing.
  #
  class AMAbstractAuthorizer < OMF::Common::LObject
    
    attr_reader :account
    
    def can_create_account?
      raise InsufficientPrivilegesException.new
    end
    
    def authorizer.can_view_account?(account)
      raise InsufficientPrivilegesException.new
    end
    
    def can_renew_account?(account, expiration_time)
      raise InsufficientPrivilegesException.new
    end
    
    def can_close_account?(account)
      raise InsufficientPrivilegesException.new
    end
    
    def can_view_resource?(resource)
      raise InsufficientPrivilegesException.new
    end
    
    def can_release_resource?(resource)
      raise InsufficientPrivilegesException.new      
    end
    
    def initialize(account)
      @account = account
    end
    
  end # class
  
end