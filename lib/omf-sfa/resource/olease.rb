
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/component_lease'

module OMF::SFA::Resource

  class OLease < OComponent #OResource

    property :valid_from, DataMapper::Property::DateTime
    property :valid_until, DataMapper::Property::DateTime

    has n, :component_leases, :child_key => [:lease_id]
    has n, :components, :model => 'OComponent', :through => :component_leases, :via => :component

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/rspec/0.1'
    sfa_class 'lease', :namespace => :omf
    sfa :valid_from, :attribute => true
    sfa :valid_until, :attribute => true

  end
end
