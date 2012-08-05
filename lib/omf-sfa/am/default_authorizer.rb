
require 'omf_common/lobject'
require 'omf-sfa/resource'

module OMF::SFA::AM

  class InsufficientPrivilegesException < AMManagerException; end  

  # This class implements an authorizer which 
  # only allows actions which have been enabled in a permission
  # hash.
  #
  class AMDefaultAuthorizer < OMF::Common::LObject
    
    attr_reader :account
    
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
    
    def initialize(account, permissions = {})
      @account = account
      @permissions = permission
    end
    
  end # class
  
end
