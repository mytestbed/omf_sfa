
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a user in the system.
  #
  class User < OResource
    has n, :project_memberships
    has n, :projects, :through => :project_memberships, :via => :project

    def to_hash_long(h, objs, opts = {})
      super
      h[:projects] = self.projects.map do |p|
        p.to_hash_brief(opts)
      end
      h
    end

  end # User
end # module