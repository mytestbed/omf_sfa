
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/component_lease'

module OMF::SFA::Resource

  class OLease < OResource

    oproperty :valid_from, DataMapper::Property::Time
    oproperty :valid_until, DataMapper::Property::Time
    oproperty :status, DataMapper::Property::Enum[:pending, :accepted, :active, :past, :cancelled]

    has n, :component_leases, :child_key => [:lease_id]
    has n, :components, :model => 'OComponent', :through => :component_leases, :via => :component

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa_class 'lease', :namespace => :ol
    sfa :name, :attribute => true
    #sfa :uuid, :attribute => true
    sfa :valid_from, :attribute => true
    sfa :valid_until, :attribute => true

    [:pending, :accepted, :active, :past, :cancelled].each do |s|
      define_method(s.to_s + '?') do
        if self.status.eql?(s.to_s)
          true
        else
          false
        end
      end
    end

    def status
      s = oproperty_get(:status)
      if s.nil?
        oproperty_set(:status, "pending")
      else
        s
      end
    end

    def to_sfa_ref_xml(res_el, obj2id, opts)
      if obj2id.key?(self)
        el = res_el.add_child(Nokogiri::XML::Element.new('lease_ref', res_el.document))
        #el.set_attribute('component_id', self.component_id.to_s)
        el.set_attribute('id_ref', self.uuid.to_s)
      else
        self.to_sfa_xml(res_el, obj2id, opts)
      end
    end

  end
end
