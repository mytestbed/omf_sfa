require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/project_membership'
require 'omf-sfa/resource/user'

module OMF::SFA::Resource

  # This class represents a Project which is strictly connected to the notion of the Slice/Account
  #
  class Project < OResource

    #has 1, :account, :model => 'OAccount', :required => false
    oproperty :account, :account, :inverse => :project

    oproperty :users, :user, :functional => false, :inverse => :projects
    # has n, :project_memberships
    # has n, :users, :through => :project_memberships, :via => :user

    def to_hash_long(h, objs, opts = {})
      super
      href_only = opts[:level] >= opts[:max_level]
      h[:users] = self.users.map do |p|
        href_only ? p.href : p.to_hash(objs, opts)
      end
      h
    end

  end
end
