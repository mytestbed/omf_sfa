
require 'omf-sfa/resource/ocomponent'

module OMF::SFA::Resource

  class Channel < OComponent

    oproperty :interface, :interface, :functional => false
    oproperty :number, Integer
    oproperty :frequency, String

    # we have already added that in olease
    #sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa_class 'channel', :namespace => :ol
    sfa :number, :attribute => true
    sfa :frequency, :attribute => true
    sfa :interfaces, :inline => true, :has_many => true, :inverse => :channel

    def _from_sfa_interfaces_property_xml(resource_el, props, context)
      resource_el.children.each do |el|
        next unless el.is_a? Nokogiri::XML::Element
        next unless el.name == 'interface_ref' # should check namespace as well

        unless client_id_attr = el.attributes['client_id']
          raise "Expected 'client_id' attr in '#{el}'"
        end
        unless interface = context[client_id_attr.value]
          raise "Referencing unknown interface '#{client_id_attr.value} in '#{el}'"
        end
        #puts "INTERFACE '#{client_id_attr.value}' => '#{interface}'"
        self.interfaces << interface
      end
    end

    # Override xml serialization of 'interface'
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'interfaces'
        value.each do |iface|
          iface.to_sfa_ref_xml(res_el, obj2id, opts)
        end
        return
      end
      super
    end

  end

end # OMF::SFA
