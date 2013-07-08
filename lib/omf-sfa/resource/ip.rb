require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource

  class Ip < OResource

    oproperty :address, String
    oproperty :netmask, String
    oproperty :ip_type, String

    belongs_to :interface, :required => false

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'ip_address'
    sfa :address, :attribute => true
    sfa :netmask, :attribute => true
    sfa :ip_type, :attribute => true, :attribute_name => 'type' # we need to override 'type' with 'ip_type' because there is conflict with 'type' property of OResource

    # override xml serialization of "ip_type" to "type"
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'ip_type'
        res_el.set_attribute('type', value.to_s)
      else
        super
      end
    end

    # def _from_sfa_ip_type_property_xml(resource_el, props, context)
      # puts ">>>>> ADDRESSE #{resource_el}"
    # end

    def to_hash(objs = {}, opts = {})
      h = {}
      uuid = h[:uuid] = self.uuid.to_s
      objs[self] = true
      to_hash_long(h, objs.merge(brief: true), opts)
      h
    end

    def to_hash_brief(opts = {})
      to_hash(opts)
    end
  end

end # OMF::SFA::Resource

