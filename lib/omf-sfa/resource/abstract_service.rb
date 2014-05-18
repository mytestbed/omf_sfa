
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a service attached to a resource
  #
  class AbstractService < OMF::SFA::Resource::OResource
    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

  end
end

