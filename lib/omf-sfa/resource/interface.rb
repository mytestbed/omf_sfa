require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/ip'

module OMF::SFA::Resource

  class Interface < OComponent

    #property :hardware_type, String
    oproperty :role, String
    oproperty :node, :node
    oproperty :channel, :channel
    oproperty :ip_addresses, OMF::SFA::Resource::Ip, :functional => false

    has 1, :ip

    def sliver
      node.sliver
    end

    sfa_class 'interface'

    #sfa :hardware_type, String, :attr_value => :name, :has_many => true
    #sfa :public_ipv4, :ip4, :attribute => true
    sfa :role, :attribute => true
    sfa :ip

    # @see IComponent
    #
    def independent_component?
      false
    end

    def to_sfa_ref_xml(res_el, obj2id, opts)
      if obj2id.key?(self)
        el = res_el.add_child(Nokogiri::XML::Element.new('interface_ref', res_el.document))
        el.set_attribute('component_id', self.component_id.to_s)
        el.set_attribute('id_ref', self.uuid.to_s)
      else
        self.to_sfa_xml(res_el, obj2id, opts)
      end
    end

    #Override xml serialization of 'ip'
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'ip'
        value.to_sfa_xml(res_el, obj2id, opts)
        return
      end
      super
    end

    def _from_sfa_ip_property_xml(resource_el, props, context)
      resource_el.children.each do |el|
        next unless el.is_a? Nokogiri::XML::Element
        next unless el.name == 'ip' # should check namespace as well

        unless address_attr = el.attributes['address']
          raise "Expected 'address' attr for ip in '#{el}'"
        end
        address = address_attr.value
        ip = self.ip_addresses.find do |r|
          r.address == address
        end
        unless ip
          # doesn't exist yet, create new one
          ip = Ip.new(:interface => self)
        end
        #puts "IP -----"
        ip.from_sfa(el)
        #puts "IP '#{ip.inspect}'"
        self.ip_addresses << ip
      end
    end


  end # Interface

end # OMF::SFA::Resource
