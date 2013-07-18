
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a user in the system.
  #
  class User < OResource

    oproperty :projects, :project, :functional => false, :inverse => :users

    # has n, :project_memberships
    # has n, :projects, :through => :project_memberships, :via => :project

    def to_hash_long(h, objs, opts = {})
      super
      href_only = opts[:level] >= opts[:max_level]
      h[:projects] = self.projects.map do |p|
        href_only ? p.href : p.to_hash(objs, opts)
      end
      h
    end

  end # User
end # module