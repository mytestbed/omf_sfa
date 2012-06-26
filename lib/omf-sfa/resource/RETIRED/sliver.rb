require 'rubygems'
require 'dm-core'

require 'omf-sfa/resource/component'

module OMF::SFA::Resource
  
  class Sliver < OMF::Common::MObject
    include DataMapper::Resource
    
    property :name, String

    has n, :nodes
    has n, :channels
    
    # managing dm objct
    property :id,   Serial

    @@def_sliver = nil
    
    def self.def_sliver
      @@def_sliver ||= self.first_or_create(:name => '__DEFAULT__')
    end
    
    def components
      [self.nodes, self.channels].flatten
    end
      
  end
  
end # OMF::SFA