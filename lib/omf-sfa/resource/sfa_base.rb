
require 'nokogiri'
require 'time'
require 'omf_base/lobject'

require 'omf-sfa/resource/gurn'
require 'omf-sfa/resource/constants'



module OMF::SFA
  module Resource

    module Base

      SFA_NAMESPACE_URI = "http://www.geni.net/resources/rspec/3"
      OMF_NAMESPACE_URI = "http://schema.mytestbed.net/rspec/3"

      module ClassMethods

        def default_domain()
          Constants.default_domain
        end

        def default_component_manager_id()
          Constants.default_component_manager_id
        end

        @@sfa_defs = {}
        @@sfa_namespaces = {}
        @@sfa_namespace2prefix = {}
        @@sfa_classes = {}
        @@sfa_name2class = {}
        @@sfa_suppress_id = {}
        @@sfa_suppress_uuid = {}

        #
        # @opts
        #   :namespace
        #
        def sfa_class(name = nil, opts = {})
          if name
            name = _sfa_add_ns(name, opts)
            #sfa_defs()['_class_'] = name
            @@sfa_classes[self] = name
            @@sfa_name2class[name] = self
          else
            @@sfa_classes[self]
            #sfa_def_for('_class_')
          end
        end

        def sfa_add_namespace(prefix, urn, options = {})
          options[:urn] = urn
          @@sfa_namespaces[prefix] = options
          @@sfa_namespace2prefix[urn] = prefix
        end

        def _sfa_prefix_for_namespace(urn)
          @@sfa_namespace2prefix[urn]
        end

        def sfa_add_namespaces_to_document(doc)
          root = doc.root
          root.add_namespace(nil, SFA_NAMESPACE_URI)
          root.add_namespace('omf', OMF_NAMESPACE_URI)
          @@sfa_namespaces.each do |name, opts|
            root.add_namespace(name.to_s, opts[:urn]) #'omf', 'http://tenderlovemaking.com')
          end
        end

        def sfa_suppress_id
          @@sfa_suppress_id[self] = true
        end

        def sfa_suppress_id?
          @@sfa_suppress_id[self] == true
        end

        def sfa_suppress_uuid
          @@sfa_suppress_uuid[self] = true
        end

        def sfa_suppress_uuid?
          @@sfa_suppress_uuid[self] == true
        end

        # Define a SFA property
        #
        # @param [Symbol] name name of resource in RSpec
        # @param [Hash] opts options to further describe mappings
        # @option opts [Boolean] :inline ????
        # @option opts [Boolean] :has_manny If true, can occur multiple time forming an array
        # @option opts [Boolean] :attribute If true, ????
        # @option opts [String] :attr_value ????
        #
        def sfa(name, opts = {})
          name = name.to_s
          props = sfa_defs() # get all the sfa properties of this class
          props[name] = opts
          # recalculate sfa properties of the descendants
          descendants.each do |c| c.sfa_defs(false) end
        end

        # opts:
        #   :valid_for - valid [sec] from now
        #
        def to_rspec(resources, type, opts = {})
          doc = Nokogiri::XML::Document.new
          #<rspec expires="2011-09-13T09:07:09Z" generated="2011-09-13T09:07:09Z" type="advertisement" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/ad.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/schema/sfa/rspec/1/ad-reservation.xsd">
          root = doc.add_child(Nokogiri::XML::Element.new('rspec', doc))

          root.set_attribute('type', type)
          now = Time.now
          root.set_attribute('generated', now.iso8601)

          case opts[:type] = type = type.to_sym
          when :manifest
            schema = 'manifest.xsd'
          when :advertisement
            schema = 'ad.xsd'
            root.set_attribute('expires', (now + (opts[:valid_for] || 600)).iso8601)
          when :request
            schema = 'request.xsd'
          else
            raise "Unnown Rspec type '#{type}'"
          end

          root.add_namespace(nil, SFA_NAMESPACE_URI)
          root.add_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")
          #root['xsi:schemaLocation'] = "#{SFA_NAMESPACE_URI} #{SFA_NAMESPACE_URI}/#{schema} #{@@sfa_namespaces[:ol]} #{@@sfa_namespaces[:ol]}/ad-reservation.xsd"
          @@sfa_namespaces.each do |prefix, opts|
            root.add_namespace(prefix.to_s, opts[:urn])
          end

          #root = doc.create_element('rspec', doc)
          #doc.add_child root
          obj2id = {}
          _to_sfa_xml(resources, root, obj2id, opts)
        end

        def from_sfa(resource_el, context = {}, type = 'manifest')
          resource = nil
          uuid = nil
          comp_gurn = nil

          unless (href = resource_el.namespace.href) == SFA_NAMESPACE_URI
            unless prefix = _sfa_prefix_for_namespace(href)
              warn "Ignoring unknown element '#{resource_el.name}' - NS: '#{resource_el.namespace.href}'"
              return
            end
            ns_opts = @@sfa_namespaces[prefix]
            return if ns_opts[:ignore]
          end

          client_id_attr = resource_el.attributes['client_id']
          client_id = client_id_attr ? client_id_attr.value : nil

          if uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['idref'])
            uuid = UUIDTools::UUID.parse(uuid_attr.value)
            if resource = OMF::SFA::Resource::OResource.first(:uuid => uuid)
              context[client_id] = resource if client_id
              return resource.from_sfa(resource_el, context, type)
            end
          end

          # TODO: Clarify the role of 'sliver_id' vs. 'component_id'
          if comp_id_attr = resource_el.attributes['sliver_id'] || resource_el.attributes['component_id']
            comp_id = comp_id_attr.value
            comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
            #begin
            if uuid = comp_gurn.uuid
              resource = OMF::SFA::Resource::OResource.first(:uuid => uuid)
              context[client_id] = resource if client_id
              return resource.from_sfa(resource_el, context, type)
            end
            if resource = OMF::SFA::Resource::OComponent.first(:urn => comp_gurn)
              context[client_id] = resource if client_id
              return resource.from_sfa(resource_el, context, type)
            end
          else
            # need to create a comp_gurn (the link is an example of that)
            unless client_id
              raise "Need 'client_id' for resource '#{resource_el}'"
            end
            if sliver_id_attr = resource_el.attributes['sliver_id']
              sliver_gurn = OMF::SFA::Resource::GURN.parse(sliver_id_attr.value)
              #puts "SLIVER_ID name: #{sliver_gurn.name} short: #{sliver_gurn.short_name} uuid: #{sliver_gurn.uuid}"
            else
              if type == 'request'
                sliver_gurn = OMF::SFA::Resource::GURN.create(client_id, type: resource_el.name, domain: 'unknown')
              else
                raise "Need 'sliver_id' for resource '#{resource_el}'"
              end
            end
            #puts "TYPE: #{type} - #{sliver_gurn}"
            # opts = {
              # :domain => sliver_gurn.domain,
              # :type => resource_el.name  # TODO: This most likely will break with NS
            # }
            # comp_gurn = OMF::SFA::Resource::GURN.create("#{sliver_gurn.short_name}:#{client_id}", opts)
            comp_gurn = sliver_gurn
            if resource = OMF::SFA::Resource::OComponent.first(:urn => comp_gurn)
              context[client_id] = resource if client_id
              resource.from_sfa(resource_el, context, type)
              resource.save
              return
            end
          end

          # Appears the resource doesn't exist yet, let's see if we can create one
          type = resource_el.name #comp_gurn.type
          if res_class = @@sfa_name2class[type]
            resource = res_class.new(:name => comp_gurn.short_name, :urn => comp_gurn)
            #puts ">>> #{comp_gurn} - #{resource.to_hash}"
            context[client_id] = resource if client_id
            resource.from_sfa(resource_el, context, type)
            #puts "22>>> #{resource.to_hash}"
            return
          end
          raise "Unknown resource type '#{type}' (#{@@sfa_name2class.keys.join(', ')})"
        end

        def _to_sfa_xml(resources, root, obj2id, opts = {})
          #puts "RRRXXX> #{resources}"
          if resources.kind_of? Enumerable
            #puts "RRRXXX2> #{resources}"
            resources.each do |r|
              #puts "R3> #{r}"
              _to_sfa_xml(r, root, obj2id, opts)
            end
          # elsif resources.kind_of? OMF::SFA::Resource::OGroup
            # # NOTE: Should be adding a GROUP element!
            # resources.each_resource do |r|
              # _to_sfa_xml(r, root, obj2id, opts)
            # end
          else
            resources.to_sfa_xml(root, obj2id, opts)
          end
          root.document
        end

        # Return all the property definitions for this class.
        #
        # +cached+ - If false, recalculate
        #
        def sfa_defs(cached = true)
          unless cached && props = @@sfa_defs[self]
            # this assumes that all the properties of the super classes are already set
            props = {}
            klass = self
            while klass = klass.superclass
              if sp = @@sfa_defs[klass]
                props = sp.merge(props)
              end
            end
            #puts "PROP #{self}:#{props.keys.inspect}"
            @@sfa_defs[self] = props
          end
          props
        end

        def sfa_def_for(name)
          sfa_defs()[name.to_s]
        end

        def sfa_cast_property_value(value, property_name, context, type = nil)
          name = property_name.to_s
          unless type
            pdef = sfa_def_for(name)
            raise "Unknow SFA property '#{name}'" unless pdef
            type = pdef[:type]
          end
          if type.kind_of?(Symbol)
            if type == :boolean
              unless value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
                raise "Wrong type for '#{name}', is #{value.type}, but should be #{type}"
              end
            else
              raise "Unknown type '#{type}', use real Class"
            end
          elsif !(value.kind_of?(type))
            if type.respond_to? :sfa_create
              value = type.sfa_create(value, context)
            else
              raise "Wrong type for '#{name}', is #{value.class}, but should be #{type}"
            end
  #          puts "XXX>>> #{name}--#{! value.kind_of?(type)}--#{value.class}||#{type}||#{pdef.inspect}"

          end
          value
        end

        def _sfa_add_ns(name, opts = {})
          if ns = opts[:namespace]
            unless @@sfa_namespaces[ns]
              raise "Unknown namespace '#{ns}'"
            end
            name = "#{ns}:#{name}"
          end
          name
        end

        def descendants
          result = []
          ObjectSpace.each_object(Class) do |klass|
            result = result << klass if klass < self
          end
          result
        end

      end # ClassMethods

      module InstanceMethods

        def resource_type
          sfa_class
        end

        def component_id
          unless id = attribute_get(:component_id)
            #self.component_id ||= GURN.create(self.uuid.to_s, self)
            #return GURN.create(self.uuid.to_s, { :model => self.class })
            return GURN.create(self.urn, { :model => self.class })
          end
          id
        end
        #
        # def component_id=(value)
          # self.component_uuid = value
        # end

        def component_manager_id
          unless uuid = attribute_get(:component_manager_id)
            return (self.class.default_component_manager_id ||= GURN.create("authority+am"))
          end
          uuid
        end

        # def component_name
          # self.name || 'unknown'
        # end

        def default_domain
          self.class.default_domain()
        end


        # def sfa_id=(id)
          # @sfa_id = id
        # end

        def sfa_id()
          #@sfa_id ||= "c#{object_id}"
          self.uuid.to_s
        end

        def sfa_class()
          self.class.sfa_class()
        end

        # def sfa_property_set(name, value)
          # value = self.class.sfa_cast_property_value(value, name, self)
          # instance_variable_set("sfa_#{name}", value)
        # end

        def sfa_property(name)
          instance_variable_get("sfa_#{name}")
        end

        def _xml_name()
          if pd = self.sfa_class
            return pd
          end
          self.class.name.gsub('::', '_')
        end

        def to_sfa_short_xml(parent)
          n = parent.add_child(Nokogiri::XML::Element.new('resource', parent.document))
          n.set_attribute('type', _xml_name())
          n.set_attribute('status', 'unimplemented')
          n.set_attribute('name', component_name())
          n
        end

        #
        # Return all SFA related properties as a hash
        #
        # +opts+
        #   :detail - detail to reveal about resource 0..min, 99 .. max
        #
        def to_sfa_hash(href2obj = {}, opts = {})
          res = to_sfa_hash_short(opts)
          res['comp_gurn'] = self.urn
          href = res['href']
          if obj = href2obj[href]
            # have described myself before
            raise "Different object with same href '#{href}'" unless obj == self
            return res
          end
          href2obj[href] = self

          defs = self.class.sfa_defs()
          #puts ">> #{defs.inspect}"
          defs.keys.sort.each do |k|
            next if k.start_with?('_')
            pdef = defs[k]
            pname = pdef[:prop_name] ||k
            v = send(pname.to_sym)
            if v.nil?
              v = pdef[:default]
            end
            #puts "!#{k} => '#{v}' - #{self}"
            unless v.nil?
              m = "_to_sfa_#{k}_property_hash".to_sym
              if self.respond_to? m
                res[k] = send(m, v, pdef, href2obj, opts)
                #puts ">>>> #{k}::#{res[k]}"
              else
                res[k] = _to_sfa_property_hash(v, pdef, href2obj, opts)
              end
            end
          end
          res
        end

        def to_sfa_hash_short(opts = {})
          uuid = self.uuid.to_s
          href_prefix = opts[:href_prefix] ||= default_href_prefix
          {
            'name' => self.name,
            'uuid' => uuid,
            'sfa_class' => sfa_class(),
            'href' => "#{href_prefix}/#{uuid}"
          }
        end

        def _to_sfa_property_hash(value, pdef, href2obj, opts)
          if !value.kind_of?(String) && value.kind_of?(Enumerable)
            value.collect do |o|
              if o.respond_to? :to_sfa_hash
                o.to_sfa_hash_short(opts)
              else
                o.to_s
              end
            end
          else
            value.to_s
          end
        end

        #
        # +opts+
        #   :detail - detail to reveal about resource 0..min, 99 .. max
        #
        def to_sfa_xml(parent = nil, obj2id = {}, opts = {})
          if parent.nil?
            parent = Nokogiri::XML::Document.new
          end
          _to_sfa_xml(parent, obj2id, opts)
          parent
        end

        def _to_sfa_xml(parent, obj2id, opts)
          new_element = parent.add_child(Nokogiri::XML::Element.new(_xml_name(), parent.document))
          if parent.document == parent
            # first time around, add namespace
            self.class.sfa_add_namespaces_to_document(parent)
          end
          defs = self.class.sfa_defs()
          if (!(opts[:suppress_id] || self.class.sfa_suppress_id?) && id = obj2id[self])
            new_element.set_attribute('idref', id)
            return parent
          end

          id = sfa_id()
          obj2id[self] = id
          unless opts[:suppress_id] || self.class.sfa_suppress_id?
            new_element.set_attribute('id', id) #if detail_level > 0
          end

          unless opts[:suppress_uuid] || self.class.sfa_suppress_uuid?
            new_element.set_attribute('omf:uuid', self.uuid) #if detail_level > 0
          end

          #if href = self.href(opts)
          #  new_element.set_attribute('omf:href', href)
          #end
          level = opts[:level] ? opts[:level] : 0
          opts[:level] = level + 1
          sfa_type = opts[:type]
          is_request = sfa_type == :request
          defs.keys.sort.each do |key|
            next if key.start_with?('_')
            pdef = defs[key]
            #puts ">>>> PDEF(#{key}): #{pdef}"
            if (ilevel = pdef[:include_level])
              #next if level > ilevel
            end
            next if is_request && pdef[:in_request] == false

            if respond_to?(m = "_to_sfa_xml_#{key}".to_sym)
              send(m, new_element, pdef, obj2id, opts)
              next
            end
            pname = (pdef[:prop_name] || key).to_sym
            #puts ">>>> #{pname} <#{self}> #{pdef.inspect}"
            next unless respond_to? pname
            value = send(pname)
            #puts "#{key} <#{value} - #{value.class}> #{pdef.inspect}"
            if value.nil?
              value = pdef[:default]
            end
            unless value.nil?
              #if detail_level > 0 || k == 'component_name'
              if value.is_a?(Time)
                value = value.xmlschema # xs:dateTime
              end
              _to_sfa_property_xml(key, value, new_element, pdef, obj2id, opts)
              #end
            end
          end
          opts[:level] = level # restore original level
          new_element
        end

        def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
          pname = self.class._sfa_add_ns(pname, pdef)
          if value.respond_to?(:to_sfa_xml)
            value.to_sfa_xml(res_el, obj2id, opts)
            return
          end

          if pdef[:attribute]
            res_el.set_attribute(pname, value.to_s)
          elsif aname = pdef[:attr_value]
            el = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
            el.set_attribute(aname, value.to_s)
          else
            if pdef[:inline] == true
              cel = res_el
            else
              cel = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
            end
            #puts ">>> _to_sfa_property_xml(#{pname}): class: #{value.class} string? #{value.kind_of?(String)} enumerable: #{value.kind_of?(Enumerable)} "
            if !value.kind_of?(String) && (value.kind_of?(Enumerable) || value.is_a?(OMF::SFA::Resource::OPropertyArray))
              value.each do |v|
                if v.respond_to?(:to_sfa_xml)
                  v.to_sfa_xml(cel, obj2id, opts)
                else
                  el = cel.add_child(Nokogiri::XML::Element.new(pname, cel.document))
                  #puts (el.methods - Object.new.methods).sort.inspect
                  el.content = v.to_s
                  #el.set_attribute('type', (pdef[:type] || 'string').to_s)
                end
              end
            else
              cel.content = value.to_s
              #cel.set_attribute('type', (pdef[:type] || 'string').to_s)
            end
          end
        end

        #
        # @param context Already defined resources in this context
        #
        def from_sfa(resource_el, context = {}, type = 'manifest')
          els = {} # this doesn't work with generic namespaces
          resource_el.children.each do |el|
            next unless el.is_a? Nokogiri::XML::Element
            unless ns = el.namespace
              raise "Missing namespace declaration for '#{el}'"
            end
            name = el.name
            unless ns.href == SFA_NAMESPACE_URI
              unless prefix = self.class._sfa_prefix_for_namespace(ns.href)
                warn "#{resource_el.name}: Ignoring unknown element '#{el.name}' - NS: '#{ns.href}'"
                next
              end
              name = "#{prefix}__#{name}"
            end
            (els[el.name] ||= []) << el
          end

          #puts ">>>>> #{self} - #{self.class.sfa_defs.keys}"
          self.class.sfa_defs.each do |name, props|
            mname = "_from_sfa_#{name}_property_xml".to_sym
            #puts "#{self}; Checking for #{mname} - #{props[:attribute]} - #{self.respond_to?(mname)}"
            if self.respond_to?(mname)
              send(mname, resource_el, props, context)
            elsif props[:attribute] == true
              #puts "Checking '#{name}'"
              next if name.to_s == 'component_name' # skip that one for the moment
              if v = resource_el.attributes[props[:attribute_name] || name]
                #puts "#{name}::#{name.class} = #{v}--#{v.class} (#{props})"
                name = props[:prop_name] || name
                send("#{name}=".to_sym, v.value)
              end
            elsif arr = els[name.to_s]
              #puts "Handling #{name} -- #{props}"
              name = props[:prop_name] || name
              arr.each do |el|
                #puts "#{self}: #{name} = #{el.text}"
                send("#{name}=".to_sym, el.text)
              end
            # else
              # puts "Don't know how to handle '#{name}' (#{props})"
            end
          end
          unless self.save
            raise "Couldn't save resource '#{self}'"
          end
          return self
        end
      end # InstanceMethods

    end # Base
  end # Resource
end # OMF::SFA

#DataMapper::Model.append_extensions(OMF::SFA::Resource::Base::ClassMethods)
#DataMapper::Model.append_inclusions(OMF::SFA::Resource::Base::InstanceMethods)
