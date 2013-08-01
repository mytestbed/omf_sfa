
require 'set'
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # Groups contain other resources including other groups
  #
  class OGroup < OResource
    #include DataMapper::Resource
    #property :id,   Serial

    has n, :group_memberships, :child_key => [ :group_id ]
    has n, :contains_resources, OResource, :through => :group_memberships, :via => :o_resource

    # Return true if this resource is a Group
    def group?
      true
    end

    # Unlink all resources within this group.
    #
    # Note: Maybe should trigger
    # an event for those resources no longer belonging to any group
    #
    def empty_group
      self.group_memberships.each {|m| m.destroy}
    end

    # Set membership to +member_a+. Removes any existing members which aren't listed
    # in +member_a+.
    #
    def members=(member_a)
      ms = member_a.to_set
      self.group_memberships.each do |m|
        unless ms.delete?(m.o_resource)
          m.destroy # no longer member
        end
      end
      # add remaining, new members
      ms.each do |m| self.contains_resources << m end
      self.contains_resources
    end

    def members
      self.contains_resources
    end

    def add_members(member_a)
      member_a.each do |r|
        unless member?(r)
          self.contains_resources << r
        end
      end
    end

    # Return true if +resource+ is a DIRECT member of this group
    #
    def member?(resource)
      # NOTE: most likely very inefficient
      self.group_memberships.first(:o_resource => resource) != nil
    end

    def each_resource(&block)
      self.contains_resources().each &block
    end

    def resource_type
      'group'
    end

    # Add this resource and all contained to +set+.
    def all_resources(set = Set.new)
      set << self
      self.each_resource { |r| r.all_resources(set) }
      set
    end

    def to_hash_long(h, objs, opts = {})
      super
      href_only = opts[:level] >= opts[:max_level]
      h[:resources] = self.contains_resources.map do |r|
        href_only ? r.href : r.to_hash(objs, opts)
      end
      h
    end

    # def to_hash(objs = {}, opts = {})
      # already_described = objs.key?(self)
      # h = super(objs, opts)
      # return h if already_described
#
      # # if (prefix = opts[:href_prefix]) && ! self.name.start_with?('_')
        # # opts = opts.dup
        # # opts[:href_prefix] = "#{prefix}/#{self.name}"
      # # end
      # h[:resources] = self.contains_resources.collect do |r|
        # #puts ">>> self: #{self} - child: #{r}"
        # r.to_hash(objs, opts)
      # end
      # h
    # end

  end

end # OMF::SFA
