
require 'omf-sfa/resource/oresource'

module OMF::SFA::Resource

  # This class represents a service which executes a
  # program as part of the boot process.
  #
  # <execute command="sudo sh /local/postboot_script.sh" shell="sh"/>
  #
  class ExecuteService < AbstractService
    oproperty :command, String, required: true
    oproperty :shell, String, default: 'sh'

    sfa_class 'execute'
    sfa :command, :attribute => true
    sfa :shell, :attribute => true
  end
end

