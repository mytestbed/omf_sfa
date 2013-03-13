require 'rubygems'
require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'json'
require 'omf_common/lobject'
require 'set'

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
    include OMF::Common::Loggable
    extend OMF::Common::Loggable    
    
    include DataMapper::Resource
    include DataMapper::Validations
    
    #@@default_href_prefix = 'http://somehost/resources/'
    @@default_href_prefix = '/resources'
        
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
    
    belongs_to :account, :model => 'OAccount', :child_key  => [ :account_id ], :required => false
    
    
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
          res = oproperty_get(pname)
          if res == nil
            oproperty_set(pname, PropValueArray.new)
            res = oproperty_get(pname)
          end
          res
        end
        
        define_method "#{pname}=" do |v|
          #unless v.kind_of? Enumerable
          #  raise "property '#{pname}' expects a value of type Enumerable"
          #end

          #val = self.eval("#{pname}")
          #puts "RESPOND: '#{respond_to?(pname.to_sym)}' self:'#{self.inspect}'"
          #val = send(pname.to_sym).value#.dup
          #val = oproperty_get(pname)
          unless v.is_a? PropValueArray
            # we really want to store it as a PropValueArray
            c = PropValueArray.new
            if v.respond_to?(:each)
              v.each {|e| c << e}
            else
              c << v
            end
            v = c
            #puts "VAL is '#{val}'"
          end
          #puts "NAME is '#{name}'"
          oproperty_set(pname, v)
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
          oproperty_set(name, v)
        end 
        
      end
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
      if prefix = opts[:name_prefix]
        href = "#{prefix}/#{self.name || self.uuid.to_s}"                  
        # if self.name.start_with? '_'
          # h[:href] = prefix
        # else
          # h[:href] = "#{prefix}/#{self.name || uuid}"          
        # end
      elsif prefix = opts[:href_prefix] || @@default_href_prefix
        href = "#{prefix}/#{self.uuid.to_s}"
      end
      href
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

    def oproperty_set(pname, value)
      #puts "OPROPERTY_SET pname:'#{pname}', value:'#{value.class}', self:'#{self.inspect}'"
      pname = pname.to_sym
      if pname == :name
        self.name = value
      else 
        self.save
        prop = self.oproperties.first_or_create(:name => pname)
        prop.value = value
      end
      value
    end
    alias_method :[]=, :oproperty_set 
    
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
        name = self.name
        self.urn = GURN.create(name, self.class).to_s
      end
    end
    
    def destroy 
      self.remove_from_all_groups

      #if p = self.provided_by
      #  pa = p.provides
      #  pa.delete self
      #  r = p.save
      #  i = 0
      #end

      # first destroy all properties
      self.oproperties.all().each do |p|
        r = p.destroy
        r
      end
      p = self.oproperties.all()
      super
    end
    
    def destroy!
      destroy
      super
    end
    
    def to_json(*a)
      unless self.id
        # need an id, means I haven't been saved yet
        save
      end
      {
        'json_class' => self.class.name,
        'id'       => self.id
      }.to_json(*a)
    end 
    
    #def self.from_json(o)
    #  puts "FROM_JSON"
    #  klass = o['json_class']
    #  id = o['id']
    #  eval(klass).first(:id => id)
    #end

    def self.json_create(o)
      klass = o['json_class']
      id = o['id']
      eval(klass).first(:id => id)
    end
   
    def to_hash(objs = {}, opts = {})
      #debug "to_hash:opts: #{opts.keys.inspect}::#{objs.keys.inspect}::"
      h = {}
      uuid = h[:uuid] = self.uuid.to_s
      h[:href] = self.href(opts)
      name = self.name
      if  name && ! name.start_with?('_')
        h[:name] = self.name
      end 
      h[:type] = self.resource_type || 'unknown'
      
      return h if objs.key?(self)
      objs[self] = true
      
      _oprops_to_hash(h)
      h
    end
    
    def default_href_prefix
      @@default_href_prefix
    end
    
    def _oprops_to_hash(h)
      klass = self.class
      while klass 
        if op = @@oprops[klass]
          op.each do |k, v|
            k = k.to_sym
            unless (value = send(k)).nil?
              if value.kind_of? OResource
                value = value.uuid.to_s
              end
              if value.kind_of? Array
                next if value.empty?
                value = value.collect do |e|
                  (e.kind_of? OResource) ? e.uuid.to_s : e
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
  class PropValueArray < Array
    
    def to_json(*a)
      {
        'json_class' => self.class.name,
        'els' => self.to_a.to_json
      }.to_json(*a)
    end 
    
    def self.json_create(o)
      # http://www.ruby-lang.org/en/news/2013/02/22/json-dos-cve-2013-0269/
      v = JSON.load(o['els'])
      v
    end
    
  end
  
end # OMF::SFA

