
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/project_membership'
require 'omf-sfa/resource/user'

module OMF::SFA::Resource

  # This class represents a Project which is strictly connected to the notion of the Slice/Account
  #
  class Project < OResource

    has 1, :account, :model => 'OAccount'
    has n, :project_memberships 
    has n, :users, :through => :project_memberships, :via => :user 
  end
end
