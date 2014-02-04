
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # A reference to a resource held somewhere else.
  #
  class OReference < OResource
    oproperty :href, String

    def to_hash(objs = {}, opts = {})
      self.href()
    end
  end
end
