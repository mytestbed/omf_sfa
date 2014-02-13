require 'rubygems'
require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'omf_base/lobject'
require 'set'
require 'active_support/inflector'

#require 'omf-sfa/resource/oproperty'
autoload :OProperty, 'omf-sfa/resource/oproperty'
#require 'omf-sfa/resource/group_membership'
autoload :GroupMembership, 'omf-sfa/resource/group_membership'
autoload :OAccount, 'omf-sfa/resource/oaccount'
autoload :OGroup, 'omf-sfa/resource/ogroup'
autoload :OLease, 'omf-sfa/resource/olease'

# module OMF::SFA::Resource
  # class OResource; end
# end
#require 'omf-sfa/resource/oaccount'

module OMF::SFA::Resource

  # This is the basic resource from which all other
  # resources descend.
  #
  # Note: Can't call it 'Resource' to avoid any confusion
  # with DataMapper::Resource
  #
  class OResource
    include OMF::Base::Loggable
    extend OMF::Base::Loggable

    include DataMapper::Resource
    include DataMapper::Validations

    #@@default_href_prefix = 'http://somehost/resources/'
    @@default_href_prefix = '/resources'
    @@href_resolvers = {}

    @@oprops = {}

    # managing dm object
    property :id,   Serial
    property :type, Discriminator

    property :uuid, UUID
    property :name, String
    #property :href, String, :length => 255, :default => lambda {|r, m| r.def_href() }
    property :urn, String, :length => 255
    property :resource_type, String

    has n, :o_properties, 'OProperty'
    alias oproperties o_properties


    #has n, :contained_in_groups, :model => :Group, :through => GroupMembership
    #has n, :contained_in_groups, 'Group' #, :through => :group_membership #GroupMembership

    #has n, :group_memberships
    #has n, :groups, 'Group', :through => :group_membership #, :via => :groups

    has n, :group_memberships, :child_key => [ :o_resource_id ]
    has n, :included_in_groups, 'OGroup', :through => :group_memberships, :via => :o_group


    #belongs_to :account, :model => 'OAccount', :child_key  => [ :account_id ], :required => false

    def self.href_resolver(&block)
      @@href_resolvers[self] = block
    end

    def self.oproperty(name, type, opts = {})
      name = name.to_s

      # should check if +name+ is already used
      op = @@oprops[self] ||= {}
      opts[:__type__] = type

      if opts[:functional] == false
        # property is an array
        pname = DataMapper::Inflector.pluralize(name)
        op[pname] = opts

        define_method pname do
          res = oproperty_array_get(pname, opts[:set_filter])
          if res == nil
            oproperty_set(pname, [])
            # We make a oproperty_get in order to get the extended Array with
            # the overidden '<<' method. Check module ArrayProxy in oproperty.rb
            res = oproperty_get(pname)
          end
          #puts "PROPERTY_GET(#{pname}) #{res}"
          if rev_m = opts[:inverse]
            res.on_modified do |v, added|
              if added
                if v.respond_to?(m = "#{rev_m}_add".to_sym)
                  v.send(m, self)
                elsif v.respond_to?(m = "#{rev_m}=".to_sym)
                  v.send(m, self)
                else
                  raise "Can't find any setter '#{rev_m}' on '#{v}'"
                end
              else
                # TODO: should remove this one form the reverse side
              end
            end
          end
          res
        end

        # Add method to add a single element to a non-functional property. This
        # helps other entities to learn if this property is functional or not.
        #
        define_method "#{pname}_add" do |v|
          oproperty_array_get(pname, opts[:set_filter]) << v
          #self.send(pname.to_sym) << v
        end

        define_method "#{pname}=" do |v|
          unless v.is_a? Array
            raise "Property '#{pname}' in '#{self.class}' requires an Array in setter - #{v.inspect}"
          end
          #res = self.send(pname.to_sym)
          res = oproperty_array_get(pname, opts[:set_filter])
          res.clear # clear any old values
          #puts ">>>> SET: #{v} - #{res}"
          v.each {|it| res << it }
          res
        end
      else
        op[name] = opts

        define_method name do
          res = oproperty_get(name)
          if res.nil?
            res = opts[:default]
            if res.nil? && (self.respond_to?(m = "default_#{name}".to_sym))
              res = send(m)
            end
          end
          res
        end

        define_method "#{name}=" do |v|
          if sf = opts[:set_filter]
            v = self.send(sf, v)
          end
          return if (old = oproperty_get(name)) == v
          oproperty_set(name, v)
          if rev_m = opts[:inverse]
            if v
              if v.respond_to?(m = "#{rev_m}_add".to_sym)
                v.send(m, self)
              elsif v.respond_to?(m = "#{rev_m}=".to_sym)
                v.send(m, self)
              else
                raise "Can't find any setter '#{rev_m}' on '#{v}'"
              end
            else
              # TODO: should remove this one form the reverse side
            end
          end
        end

      end
    end

    def self.prop_all(query)
      OProperty.prop_all(query, self)
    end

    # Clone this resource this resource. However, the clone will have a unique UUID
    #
    def clone()
      clone = self.class.new
      attributes.each do |k, v|
        next if k == :id || k == :uuid
        clone.attribute_set(k, DataMapper::Ext.try_dup(v))
      end
      oproperties.each do |p|
        clone.oproperty_set(p.name, DataMapper::Ext.try_dup(p.value))
      end

      clone.uuid = UUIDTools::UUID.random_create
      return clone
    end

    def uuid()
      unless uuid = attribute_get(:uuid)
        uuid = self.uuid = UUIDTools::UUID.random_create
      end
      uuid
    end

    def href(opts = {})
      klass = self.class
      while (resolver = @@href_resolvers[klass]).nil?
        break if (klass = klass.superclass) == Object
      end
      if resolver
        href = resolver.call(self, opts)
      end
      unless href
        href = "/resources/#{self.uuid.to_s}"
      end

      # if prefix = opts[:name_prefix]
        # href = "#{prefix}/#{self.name || self.uuid.to_s}"
      # elsif opts[:href_use_class_prefix]
        # #href = "/#{self.resource_type}/#{self.name || self.uuid.to_s}"
        # href = "/#{self.resource_type.pluralize}/#{self.uuid.to_s}"
      # elsif prefix = opts[:href_prefix] || @@default_href_prefix
        # href = "#{prefix}/#{self.uuid.to_s}"
      # end
      href
    end

    def resource_type()
      unless rt = attribute_get(:resource_type)
        rt = self.class.to_s.split('::')[-1].downcase
      end
      rt
    end


    # Return the status of the resource. Should be
    # one of: _configuring_, _ready_, _failed_, and _unknown_
    #
    def status
      'unknown'
    end

    def oproperty(pname)
      self.oproperties.first(:name => pname.to_sym)
    end


    def oproperty_get(pname)
      #puts "OPROPERTY_GET: pname:'#{pname}'"
      pname = pname.to_sym
      return self.name if pname == :name

      prop = self.oproperties.first(:name => pname)
      prop.nil? ? nil : prop.value
    end
    alias_method :[], :oproperty_get

    def oproperty_set(pname, value, type = nil)
      #puts "OPROPERTY_SET pname:'#{pname}', value:'#{value.class}'-#{type}, self:'#{self.inspect}'"
      pname = pname.to_sym
      if pname == :name
        self.name = value
      else
        self.save
        #puts ">>>>>" + @@oprops[self.class][pname.to_s].to_s
        prop = self.oproperties.first_or_create(:name => pname)
        prop.value = value
      end
      value
    end
    alias_method :[]=, :oproperty_set

    def oproperty_array_get(pname, set_filter)
      pname = pname.to_sym
      unless ap = (@array_properties ||= {})[pname]
        ap = OPropertyArray.new(self, pname)
        if set_filter
          # TODO: The following block can most likely be optimised away
          ap.on_set do |v|
            self.send(set_filter, v)
          end
        end
        @array_properties[pname] = ap
      end
      ap
    end

    def oproperties_as_hash
      res = {}
      oproperties.each do |p|
        res[p.name] = p.value
      end
      res
    end

    def each_resource(&block)
      # resources don't contain other resources, groups do'
    end

    # alias_method :_dirty_children?, :dirty_children?
    # def dirty_children?
    # puts "CHECKING CHILDREN DIRTY: #{_dirty_children?}"
    # _dirty_children?
    # end

    alias_method :_dirty_self?, :dirty_self?
    def dirty_self?
      #puts "CHECKING DIRTY #{_dirty_self?}"
      return true if _dirty_self?
      o_properties.each do |p|
        return true if p.dirty_self?
      end
      false
    end

    # alias_method :_dirty_attributes, :dirty_attributes
    # def dirty_attributes
    # dirty = _dirty_attributes
    # puts "DIRTY ATTRIBUTE #{dirty.inspect}"
    # dirty
    # end

    # Return true if this resource is a Group
    def group?
      false
    end


    # Remove this resource from all groups it currently belongs.
    #
    def remove_from_all_groups
      self.group_memberships.each {|m| m.destroy}
    end

    # Add this resource and all contained to +set+.
    def all_resources(set = Set.new)
      set << self
      set
    end


    before :save do
      unless self.uuid
        self.uuid = UUIDTools::UUID.random_create
      end
      unless self.name
        self.name = self.urn ? GURN.create(self.urn).short_name : "r#{self.object_id}"
      end
      unless self.urn
        # The purpose or function of a URN is to provide a globally unique,
        # persistent identifier used for recognition, for access to
        # characteristics of the resource or for access to the resource
        # itself.
        # source: http://tools.ietf.org/html/rfc1737
        #
        name = self.name
        self.urn = GURN.create(name, :model => self.class).to_s
      end
    end

    def destroy
      #debug "ORESOURCE destroy #{self}"
      self.remove_from_all_groups

      #if p = self.provided_by
      #  pa = p.provides
      #  pa.delete self
      #  r = p.save
      #  i = 0
      #end

      # first destroy all properties
      self.oproperties.all().each do |p|
        #debug "ORESOURCE destroying property '#{p.inspect}'"
        r = p.destroy
        r
      end
      #p = self.oproperties.all()
      super
    end

    def destroy!
      #debug "ORESOURCE destroy! #{self}"
      destroy
      super
    end

    def to_json(*a)
      to_hash_brief().to_json(*a)

      # unless self.id
        # # need an id, means I haven't been saved yet
        # save
      # end
      # {
        # 'json_class' => self.class.name,
        # 'id'       => self.id
      # }.to_json(*a)
    end

    # def as_json(options = { })
      # raise "DO WE STILL NEED THIS"
      # {
        # "json_class" => self.class.name,
        # "id" => self.id
      # }
    # end


    #def self.from_json(o)
    #  puts "FROM_JSON"
    #  klass = o['json_class']
    #  id = o['id']
    #  eval(klass).first(:id => id)
    #end

    def self.json_create(o)
      klass = o['json_class']
      id = o['id']
      r = eval(klass).first(:id => id)
      r
    end

    def to_hash(objs = {}, opts = {})
      max_level = opts[:max_level] ||= 0
      level = opts[:level] ||= 0
      if level > max_level
        return self.href
      end

      #debug "to_hash(self):opts: #{opts.keys.inspect}::#{objs.keys.inspect}::"
      h = to_hash_brief(opts)
      return h if objs.key?(self)
      objs[self] = true
      return h if opts[:brief] || (level >= max_level)

      opts = opts.merge(level: level + 1)
      opts[:brief] = true if level > max_level
      #puts ">>>> #{opts}"
      to_hash_long(h, objs, opts)
      h
    end

    def to_hash_brief(opts = {})
      h = {}
      uuid = h[:uuid] = self.uuid.to_s
      h[:href] = self.href
      name = self.name
      if  name && ! name.start_with?('_')
        h[:name] = self.name
      end
      h[:type] = self.resource_type
      h
    end

    def to_hash_long(h, objs = {}, opts = {})
      _oprops_to_hash(h, objs, opts)
      h
    end

    def default_href_prefix
      @@default_href_prefix
    end

    def _oprops_to_hash(h, objs, opts)
      klass = self.class
      while klass
        if op = @@oprops[klass]
          op.each do |k, v|
            k = k.to_sym
            unless (value = send(k)).nil?
              #puts "OPROPS_TO_HAHS(#{k}): #{value}::#{value.class}--#{oproperty_get(k)}"
              #puts "OPROPS_TO_HAHS(#{k}): #{opts[:level]} >= #{opts[:max_level]}"
              if value.is_a? OResource
                href_only = opts[:level] >= opts[:max_level]
                value = href_only ? value.href : value.to_hash(objs, opts)
                #value = value.to_hash(objs, opts)
              end
              if value.is_a? Time
                value = value.iso8601
              end
              if value.kind_of? Array
                next if value.empty?
                opts = opts.merge(level: opts[:level] + 1)
                value = value.collect do |e|
                  #(e.kind_of? OResource) ? (href_only ? e.href : e.to_hash(objs, opts)) : e
                  (e.kind_of? OResource) ? e.to_hash(objs, opts) : e
                end
              end

              h[k] = value
            end
          end
        end
        klass = klass.superclass
      end
      h
    end
  end

  # Extend array to add functionality dealing with property values
  #class PropValueArray < Array

  #  def to_json(*a)
  #    {
  #      'json_class' => self.class.name,
  #      'els' => self.to_a.to_json
  #    }.to_json(*a)
  #  end

  #  def self.json_create(o)
  #    # http://www.ruby-lang.org/en/news/2013/02/22/json-dos-cve-2013-0269/
  #    v = JSON.load(o['els'])
  #    v
  #  end

  #end

end # OMF::SFA

