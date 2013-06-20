require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource

  class Ip < OResource

    oproperty :address, String
    oproperty :netmask, String
    oproperty :ip_type, String

    belongs_to :interface, :required => false

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'ip'
    sfa :address, :attribute => :true
    sfa :netmask, :attribute => :true
    sfa :ip_type, :attribute => :true # we need to override 'type' with 'ip_type' because there is conflict with 'type' property of OResource

    # override xml serialization of "ip_type" to "type"
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'ip_type'
        res_el.set_attribute('type', value.to_s)
      else
        super
      end
    end

  end

end # OMF::SFA::Resource

