
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

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'

    sfa_class 'lease', :namespace => :omf
    sfa :name, :attribute => true, :namespace => :omf
    sfa :valid_from, :attribute => true, :namespace => :omf
    sfa :valid_until, :attribute => true, :namespace => :omf

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

  end
end
