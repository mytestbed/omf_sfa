
require 'set'
require 'omf-sfa/resource/channel'
#require 'omf-sfa/resource/link_property'

module OMF::SFA::Resource

  # <link component_id="urn:publicid:IDN+emulab.net+link+link-pc102%3Aeth2-internet%3Aborder" component_name="link-pc102:eth2-internet:border">
    # <component_manager name="urn:publicid:IDN+emulab.net+authority+cm"/>
      # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>
      # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>
    # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+internet:border" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>
    # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>
      # <link_type name="ipv4"/>
  # </link>
  class Link < Channel

    oproperty :link_type, String
    oproperty :capacity, Integer # kbps
    oproperty :latency, Integer # ms
    oproperty :packet_loss, Float # 0 .. 1

    sfa_class 'link'
    sfa :link_type, attr_value: 'name' #:content_attribute => :name
    sfa :component_manager
    sfa :property # sets capacity, latency and packet_loss
    #sfa :properties, LinkProperty, :inline => true, :has_many => true

    #Override xml serialization of 'component_manager'
    def _to_sfa_xml_component_manager(res_el, pdef, obj2id, opts)
      cms = Set.new
      self.interfaces.each do |ifs|
        cms << ifs.node.component_manager
      end
      cms.each do |cm|
        next unless cm # not sure if 'nil' could show up her
        el = res_el.add_child(Nokogiri::XML::Element.new('component_manager', res_el.document))
        el.set_attribute('name', cm)
      end

    end

    #Override xml serialization of 'property'
    def _to_sfa_xml_property(res_el, pdef, obj2id, opts)
      capacity = self.capacity
      latency = self.latency
      packet_loss = self.packet_loss
      if capacity || latency || packet_loss
        source, dest = self.interfaces.to_a
        _to_sfa_xml_one_way_property(res_el, source, dest, capacity, latency, packet_loss)
        _to_sfa_xml_one_way_property(res_el, dest, source, capacity, latency, packet_loss)
      end
    end

    def _to_sfa_xml_one_way_property(res_el, source, dest, capacity, latency, packet_loss)
      # <property source_id="n7:if1" dest_id="n6:if2" capacity="10" latency="20" packet_loss="0.3"/>
      el = res_el.add_child(Nokogiri::XML::Element.new('property', res_el.document))
      el.set_attribute('source_id', source.client_id)
      el.set_attribute('dest_id_id', dest.client_id)
      el.set_attribute('capacity', capacity.to_i) if capacity
      el.set_attribute('latency', latency.to_i) if latency
      el.set_attribute('packet_loss', packet_loss) if packet_loss
    end
  end

end # OMF::SFA::Resource

