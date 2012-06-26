
require 'omf-sfa/am/am-rest/sliver_handler'

module OMF::SFA::AM
  
  # Handles all calls for manipulating theDEFAULT sliver which 
  # holds all the available resources in the AM.
  #    
  class DefaultSliverHandler < SliverHandler
    def initialize(opts = {})
      @opts = opts
    end
    
    def handle(env)
      req = ::Rack::Request.new(env)
      method = req.request_method
      comp_id = (req.path_info.split('/').select do |p| !p.empty? end)[0]
      
      sliver = OMF::SFA::Resource::Sliver.def_sliver
      sliver.reload
      return handle_resources(comp_id, method, sliver, req)
    end

    ###### RESOURCE COLLECTION
        
    def put_resources(sliver, req)
      raise NotAuthorizedException.new "Not authorized to modify resource list"
    end
    
    def delete_resources(sliver, req)
      raise NotAuthorizedException.new "Not authorized to remove resource list"
    end

    ###### INDIVIDUAL COMPONENTS
        
    def put_component(component_id, sliver, req)
      raise NotAuthorizedException.new "Not authorized to modify components."
    end
    
    def delete_component(component_id, sliver, req)
      raise NotAuthorizedException.new "Not authorized to delete components."
    end
    
      
  end
end

    