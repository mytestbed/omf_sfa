
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/disk_image'

module OMF::SFA::Resource

  # This class represents a disk image to be used for a particular node.
  #
  #  <sliver_type name="emulab-openvz">
  #    <disk_image name="urn:publicid:IDN+instageni.gpolab.bbn.com+image+emulab-net//GIMIomf"/>
  #  </sliver_type>
  #
  class SliverType < OResource
    oproperty :disk_image, DiskImage, required: false

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'sliver_type'
    sfa_suppress_id
    sfa :name, :attribute => true
    sfa :disk_image
  end
end

