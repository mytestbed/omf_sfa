
require 'omf_sfa'
module OMF::SFA
  module Resource
    class ResourceException < Exception; end
  end
end

require 'omf-sfa/resource/gurn'
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/oreference'
require 'omf-sfa/resource/oproperty'
require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/group_membership'
require 'omf-sfa/resource/oaccount'
require 'omf-sfa/resource/olease'
require 'omf-sfa/resource/component_lease'

#require 'omf-sfa/resource/sliver'
require 'omf-sfa/resource/link'
require 'omf-sfa/resource/interface'
require 'omf-sfa/resource/node'
require 'omf-sfa/resource/execute_service'
require 'omf-sfa/resource/install_service'
require 'omf-sfa/resource/disk_image'
