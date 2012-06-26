
require 'nokogiri'   
require 'time' 
require 'omf-common/mobject2'

require 'omf-sfa/resource/gurn'
require 'omf-sfa/resource/constants'



module OMF::SFA
  module Resource
  
    module Base
      
      SFA_NAMESPACE_URI = "http://www.protogeni.net/resources/rspec/2"
  
      module ClassMethods
        
        def default_domain()
          Constants.default_domain
        end   
        
        def default_component_manager_id()
          Constants.default_component_manager_id
        end   
        

        
        @@sfa_defs = {}
        @@sfa_namespaces = {}
        @@sfa_classes = {}
        
        # 
        # @opts
        #   :namespace
        #
        def sfa_class(name = nil, opts = {})
          if name
            name = _sfa_add_ns(name, opts)
            #sfa_defs()['_class_'] = name
            @@sfa_classes[self] = name
          else
            @@sfa_classes[self]            
            #sfa_def_for('_class_')
          end
        end
        
        def sfa_add_namespace(prefix, urn)
          @@sfa_namespaces[prefix] = urn
        end
        
        def sfa_add_namespaces_to_document(doc)
          root = doc.root
          root.add_namespace(nil, SFA_NAMESPACE_URI)
          @@sfa_namespaces.each do |name, uri|
            root.add_namespace(name.to_s, uri) #'omf', 'http://tenderlovemaking.com')
          end
        end
        

        def sfa(name, opts = {})
          name = name.to_s
          props = sfa_defs()
          props[name] = opts
          descendants.each do |c| c.sfa_defs(false) end 
        end
                
        # opts:
        #   :valid_for - valid [sec] from now
        #
        def sfa_advertisement_xml(resources, opts = {})
          doc = Nokogiri::XML::Document.new
          #<rspec expires="2011-09-13T09:07:09Z" generated="2011-09-13T09:07:09Z" type="advertisement" xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:emulab="http://www.protogeni.net/resources/rspec/ext/emulab/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.protogeni.net/resources/rspec/2 http://www.protogeni.net/resources/rspec/2/ad.xsd http://www.protogeni.net/resources/rspec/ext/emulab/1 http://www.protogeni.net/resources/rspec/ext/emulab/1/ptop_extension.xsd http://company.com/rspec/ext/stitch/1 http://company.com/rspec/ext/stitch/1/ad.xsd ">  
          root = doc.add_child(Nokogiri::XML::Element.new('rspec', doc))
          root.add_namespace(nil, SFA_NAMESPACE_URI)
          @@sfa_namespaces.each do |prefix, urn|
            root.add_namespace(prefix.to_s, urn)
          end

          root.set_attribute('type', "advertisement")
          now = Time.now
          root.set_attribute('generated', now.iso8601)
          root.set_attribute('expires', (now + (opts[:valid_for] || 600)).iso8601)

          #root = doc.create_element('rspec', doc)
          #doc.add_child root
          obj2id = {}
          _to_sfa_xml(resources, root, obj2id, opts)          
        end
        
        # def _to_sfa_xml(resources, root, obj2id, opts = {})
          # #puts "RRRXXX> #{resources}"
          # resources.each_resource do |r|
            # #puts "RRR> #{r}"
            # if r.kind_of? Enumerable
              # _to_sfa_xml(r, root, obj2id, opts)          
            # else
              # r.to_sfa_xml(root, obj2id, opts)  
            # end
#             
          # end
          # root.document   
        # end

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
          #@component_id ||= GURN.create(self.component_name, self)
          @component_id ||= GURN.create(self.uuid.to_s, self)
# 
          # puts "COMPONENT_ID: #{self.component_name}::#@component_id"
          # @component_id
        end
        
        def component_manager_id
          @component_manager_id ||= (self.class.default_component_manager_id ||= GURN.create("authority+am"))
        end
    
        def component_name
          self.name || 'unknown'
        end
        
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
          #detail_level = opts[:detail] ? opts[:detail] : 99
          res = {} #opts[:_res_] ||= {}

          #href = (opts[:href_prefix] || '/') + component_name()
          res['uuid'] = self.uuid.to_s
          res['name'] = self.name          
          href = "#{opts[:href_prefix]}/#{res['uuid']}"
          res['href'] = href
          if obj = href2obj[href]
            # have described myself before
            raise "Different object with same href '#{href}'" unless obj == self
            return res
          end
          
          href2obj[href] = self
          res['sfa_class'] = sfa_class()

          defs = self.class.sfa_defs()
          defs.keys.sort.each do |k|
            next if k.start_with?('_')
            pdef = defs[k]
            v = send(k.to_sym)
            if v.nil?
              v = pdef[:default]
            end
            unless v.nil?
              m = "_to_sfa_#{k}_property_hash".to_sym
              if self.respond_to? m
                res[k] = send(m, v, pdef, href2obj, opts)
              else
                res[k] = _to_sfa_property_hash(v, pdef, href2obj, opts)
              end
            end
          end
          res
        end
        
        def _to_sfa_property_hash(value, pdef, href2obj, opts)
          if !value.kind_of?(String) && value.kind_of?(Enumerable)
            value.collect do |o|
              if o.respond_to? :to_sfa_hash
                o.to_sfa_hash(href2obj, opts)
              # end
              # if o.respond_to?(:component_name)
                # href = (opts[:href_prefix] || '/') + o.component_name()
                # href2obj[href] = self                
                # {'href' => href, 'sfa_class' => o.sfa_class()}
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
          n = parent.add_child(Nokogiri::XML::Element.new(_xml_name(), parent.document))
          if parent.document == parent
            # first time around, add namespace
            self.class.sfa_add_namespaces_to_document(parent)
          end
          defs = self.class.sfa_defs()
          if (id = obj2id[self])
            n.set_attribute('idref', id)
            return parent
          end
          
          id = sfa_id()
          obj2id[self] = id
          n.set_attribute('id', id) #if detail_level > 0
          if href = self.href(opts)
            n.set_attribute('omf:href', href)
          end
          level = opts[:level] ? opts[:level] : 0
          opts[:level] = level + 1
          defs.keys.sort.each do |k|
            next if k.start_with?('_')
            pdef = defs[k]
            if (ilevel = pdef[:include_level])
              #next if level > ilevel
            end
            #puts ">>>> #{k} <#{self}> #{pdef.inspect}"
            v = send(k.to_sym)
            #puts "#{k} <#{v}> #{pdef.inspect}"
            if v.nil?
              v = pdef[:default]
            end
            unless v.nil?
              #if detail_level > 0 || k == 'component_name'
                _to_sfa_property_xml(k, v, n, pdef, obj2id, opts)
              #end
            end
          end
          opts[:level] = level # restore original level
          n
        end
        
        def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
          pname = self.class._sfa_add_ns(pname, pdef)
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
            if !value.kind_of?(String) && value.kind_of?(Enumerable)
              value.each do |o|
                if o.respond_to?(:to_sfa_xml)
                  o.to_sfa_xml(cel, obj2id, opts)
                else 
                  el = cel.add_child(Nokogiri::XML::Element.new(pname, cel.document))
                  #puts (el.methods - Object.new.methods).sort.inspect
                  el.content = o.to_s
                  #el.set_attribute('type', (pdef[:type] || 'string').to_s)
                end
              end
            else
              cel.content = value.to_s
              #cel.set_attribute('type', (pdef[:type] || 'string').to_s)
            end
          end
        end
      end # InstanceMethods        
      
    end # Base
  end # Resource
end # OMF::SFA

#DataMapper::Model.append_extensions(OMF::SFA::Resource::Base::ClassMethods)
#DataMapper::Model.append_inclusions(OMF::SFA::Resource::Base::InstanceMethods)
