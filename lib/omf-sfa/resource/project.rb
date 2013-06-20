require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/project_membership'
require 'omf-sfa/resource/user'

module OMF::SFA::Resource

  # This class represents a Project which is strictly connected to the notion of the Slice/Account
  #
  class Project < OResource

    has 1, :account, :model => 'OAccount', :required => false
    has n, :project_memberships
    has n, :users, :through => :project_memberships, :via => :user

    def to_hash_long(h, objs, opts = {})
      super
      h[:users] = self.users.map do |p|
        p.to_hash_brief(opts)
      end
      h
    end

  end
end
