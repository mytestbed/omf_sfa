
require 'omf_base/lobject'

module OMF::SFA::Resource
#
  class GURN #< OMF::Base::MObject

    @@def_domain = 'omf:nitos'
    @@name2obj = {}

    # Create a GURN
    #
    # @param [String] name Name of GURN
    # @param [Hash] opts options to further describe GURN components
    # @option opts [String] :type GURN's type
    # @option opts [Class] :model Class responding to either :sfa_class or :urn_type
    # @option opts [String] :domain GURN's domain
    #
    def self.create(name, opts = {})
      return name if name.kind_of? self
      #puts "GUID: #{name}###{opts}"

      obj = @@name2obj[name]
      return obj if obj

      if name.start_with?('urn')
        return parse(name)
      end

      unless type = opts[:type]
        model = opts[:model]
        if model && model.respond_to?(:sfa_class)
          type =  model.sfa_class
        elsif model && model.respond_to?(:resource_type)
          type =  model.resource_type
        end
      end
      domain = opts[:domain] || @@def_domain
      return @@name2obj[name] = self.new(name, type, domain)
    end

    def self.sfa_create(name, context = nil)
      return create(name, :model => context)
    end

    # Create a GURN object from +urn_str+.
    #
    def self.parse(urn_str)
      if urn_str.start_with? 'urn:publicid:IDN'
        a = urn_str.split('+')
        a.delete_at(0) # get rid of "urn:publicid:IDN"
        if a.length == 3
          prefix, type, name = a
        elsif a.length == 2
          prefix, name = a
          type = nil
        else
          raise "unknown format '#{urn_str}' for GURN (#{a.inspect})."
        end
        @@name2obj[urn_str] = self.new(name, type, prefix)
      else
        raise "unknown format '#{urn_str}' for GURN - expected it to start with 'urn:publicid:IDN'."
      end
    end

    def self.default_domain=(domain)
      @@def_domain = domain
    end

    def self.default_domain()
      @@def_domain
    end

    # This class maintains a cache between object name and it's GURN.
    # As this may get in the way of testing, this method provides a way
    # of clear that cache
    #
    def self.clear_cache
      @@name2obj.clear
    end

    attr_reader :name, :short_name, :type, :domain, :urn

    def initialize(short_name, type = nil, domain = nil)
      @short_name = short_name
      @domain = domain || @@def_domain
      if type
        @type =  type
        @name = "#{@domain}+#{type}+#{short_name}"
      else
        @name = "#{@domain}+#{short_name}"
      end
      @urn = 'urn:publicid:IDN+' + name
    end

    def uuid
      unless @uuid
        @uuid = UUIDTools::UUID.parse(short_name)
      end
      @uuid
    rescue ArgumentError
      @uuid = nil
    end

    def to_s
      @urn
    end

  end # GURN
end # OMF::SFA

require 'dm-core'

module DataMapper
  class Property
    class GURN < DataMapper::Property::String

      # Maximum length chosen based on recommendation:
      length 256

      def custom?
        true
      end

      def primitive?(value)
        value.kind_of?(OMF::SFA::Resource::GURN)
      end

      def valid?(value, negated = false)
        super || primitive?(value) #|| value.kind_of?(::String)
      end

      # We don't want this to be called, but the Model::Property calls
      # this one first before calling #set! on this instance again with
      # the value returned here. Hopefully this is the only place this
      # happens. Therefore, we just return +value+ unchanged and take care
      # of casting in +load2+
      #
      def load(value)
        if value
          if value.start_with?('urn')
            return OMF::SFA::Resource::GURN.create(value)
          end
          raise "BUG: Shouldn't be called anymore (#{value})"
        end
        nil
      end

      def load2(value, context_class)
        if value
          #puts "LOAD #{value}||#{value.class}||#{context.inspect}"
          return OMF::SFA::Resource::GURN.create(value, context_class)
        end
        nil
      end

      def dump(value)
        value.to_s unless value.nil?
      end

      # Typecasts an arbitrary value to a GURN
      #
      # @param [Hash, #to_mash, #to_s] value
      #   value to be typecast
      #
      # @return [GURN]
      #   GURN constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        raise "BUG: Shouldn't be called anymore"
      end

      # @override
      def set(resource, value)
        #puts ">>> SET: #{resource}"
        set!(resource, load2(value, resource.class))
      end



    end # class GURN
  end # class Property
end #module DataMapper



