
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ocomponent'

module OMF::SFA::Resource

  class OLease < OResource

    property :valid_from, DataMapper::Property::Integer
    property :valid_until, DataMapper::Property::Integer

    has n, :components, :model => 'OResource', :child_key  => [ :lease_id ], :required => false

    oproperty :provided_by, self

  end
end
