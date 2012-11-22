
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource
  
  # This class represents a user in the system.
  #
  class User < OResource
    has n, :project_memberships
    has n, :projects, :through => :project_memberships, :via => :project
  end # User
end # module
