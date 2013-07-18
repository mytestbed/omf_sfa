
#require 'time'
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/project'

module OMF::SFA::Resource

  # This class represents a users or team's account. Each resource
  # belongs to an account.
  #
  class OAccount < OGroup

    @@def_duration = 100 * 86400 # 100 days

    def self.default_duration=(duration)
      @@def_duration = duration
    end

    def self.urn_type
      'account'
    end

    oproperty :created_at, DataMapper::Property::Time
    oproperty :valid_until, DataMapper::Property::Time
    oproperty :closed_at, DataMapper::Property::Time


    oproperty :project, :project, :inverse => :project
    oproperty :active_components, :ocomponent, :functional => false, :inverse => :account
    # has n, :active_components, :model => 'OResource', :child_key  => [ :account_id ] #, :required => false
    # belongs_to :project, :required => false

    def active?
      return false unless self.closed_at.nil?

      valid_until = self.valid_until
      unless valid_until.kind_of? Time
        valid_until = Time.parse(valid_until) # seem to not be returned as Time
      end
      if Time.now > valid_until
        self.close()
        return false
      end
      true
    end

    def closed?
      ! active?
    end

    # Close account
    def close
      self.closed_at = Time.now
      save
    end

    def initialize(*args)
      super
      props = Hash.new
      args.each do |a|
        props.merge!(a)
      end
      self.created_at = Time.now
      if self.valid_until == nil
        self.valid_until = Time.now + @@def_duration
      end
    end

    def valid_until
      v = oproperty_get(:valid_until)
      if v && !v.kind_of?(Time)
        oproperty_set(:valid_until, v = Time.parse(v))
      end
      v
    end

    def resource_type()
      'account'
    end

    def to_hash_long(h, objs, opts = {})
      super
      h[:sub_accounts] = h.delete(:resources)
      href_only = opts[:level] >= opts[:max_level]
      # h[:active_resources] = self.active_components.map do |r|
        # href_only ? r.href : r.to_hash(objs, opts)
      # end
      h
    end


  end # OAccount
end # OMF::SFA::Resource
