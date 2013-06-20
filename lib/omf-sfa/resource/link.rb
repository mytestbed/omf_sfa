

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
    #has 2, :interfaces

    sfa_class 'link'
    sfa :link_type, :content_attribute => :name
    #sfa :properties, LinkProperty, :inline => true, :has_many => true

  end

end # OMF::SFA::Resource

