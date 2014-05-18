
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a disk image to be used for a particular node.
  #
  # <disk_image name="urn:publicid:IDN+instageni.gpolab.bbn.com+image+emulab-net//GIMIomf"/>
  # <disk_image version="de35e71b31771870bcdfcccb4dee11657ba145b8" name="http://emmy9.casa.umass.edu/Disk_Images/ExoGENI/exogeni-umass-ovs-1.0.2.xml"/>
  #
  class DiskImage < OResource
    oproperty :url, String, required: true
    oproperty :version, String, required: false

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'disk_image'
    sfa :name, prop_name: :url, attribute: true
    sfa :version, attribute: true
  end
end

