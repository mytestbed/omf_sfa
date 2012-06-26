
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/am/am-rest/sliver_handler'

module OMF::SFA::AM

  # Handles the collection of slivers on this AM. 
  #    
  class AllSliversCollectionHandler < RestHandler
    
    def initialize(opts)
      super
      @sliver_handler = SliverHandler.new(opts)
    end
    
    def find_handler(path, opts)
      path.empty? ? self : @sliver_handler.find_handler(path, opts)
    end
    
    def on_get(req)
      slivers = OMF::SFA::Resource::Sliver.all
      
      sa = []
      OMF::SFA::Resource::Sliver.all.each do |s|
        next if s == OMF::SFA::Resource::Sliver.def_sliver
        
        sa << {
          :name => s.name,
          :href => "/slivers/#{s.name}"
        }  
      end     
      {:slivers_response => {:slivers => sa}}
    end
  end
end
    