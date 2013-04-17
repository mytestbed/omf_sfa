

require 'omf_common/lobject'

module OMF::SFA::AM

  include OMF::Common

  class InsufficientPrivilegesException < AMManagerException; end

  # This class implements an authorizer which 
  # only allows actions which have been enabled in a permission
  # hash.
  #
  class DefaultAuthorizer < LObject
        
    [
      # ACCOUNT
      :can_create_account?, # ()
      :can_view_account?, # (account)
      :can_renew_account?, # (account, until)
      :can_close_account?, # (account)
      # RESOURCE
      :can_create_resource?, # (resource_descr, type)
      :can_view_resource?, # (resource)
      :can_release_resource?, # (resource)
      # LEASE
      :can_view_lease?, # (lease)
      :can_modify_lease?, # (lease)
      :can_release_lease?, # (lease)
    ].each do |m|
      define_method(m) do |*args|
        debug "Check permission '#{m}' (#{@permissions.inspect})"
        unless @permissions[m]
          raise InsufficientPrivilegesException.new
        end
      end
    end
    
    def initialize()
      @permissions = {}
    end
  end
end
