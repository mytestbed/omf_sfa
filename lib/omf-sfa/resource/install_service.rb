
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a service which installs a
  # program as part of the boot process.
  #
  # <install install_path="/local" url="http://emmy9.casa.umass.edu/InstaGENI_Images/install-script.tar.gz"/>
  #
  class InstallService < AbstractService
    oproperty :url, String, required: true # Location of file to install
    oproperty :install_path, String, default: '/usr/local'

    sfa_class 'install'
    sfa :url, :attribute => true
    sfa :install_path, :attribute => true
  end
end

