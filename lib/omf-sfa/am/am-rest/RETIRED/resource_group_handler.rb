
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/am/am-rest/resource_handler'

module OMF::SFA::AM

  # Handles groups of resources of all kinds.
  #    
  class ResourceGroupHandler < RestHandler
    
    def initialize(opts = {})
      super
      @res_handler = ResourceHandler.new(opts)
    end
    
    def find_handler(path, opts)
      if path.empty?
        self 
      else 
        opts[:resource_id] = path.shift
        @res_handler
      end
    end
    
    def on_get(group, opts)
      show_resource(group, opts) 
    end
    
    # def on_get(resource_uri, opts)
      # resource = _get_resource(resource_uri, nil, opts)
      # show_resource(resource, opts) 
    # end
    

    def on_put(resource_uri, opts)
      #resource = _get_resource(resource_uri, true, opts)
      
      #puts "ON_PUT_OPTS: #{opts.inspect}"
      body, format = parse_body(opts)
      case format
      # when :empty
        # # do nothing
      when :xml
        modifier_el = body.root
        resource = put_resource_xml(modifier_el, resource_uri, opts)
      else
        raise UnsupportedBodyFormatException.new(format)
      end
      show_resource(resource, opts)
    end

    
    def on_delete(group, opts)
      empty_group(group, opts)
      show_group(nil, opts)
    end
    
    
    ####################################
        
    # Modify or create/modify component
    #
    # +modifier+ - object describing modifications to component
    #
    def put_resource_xml(modifier_el, resource_uri, opts)
      unless cid_attr = modifier_el['component_id']
        raise BadRequestException.new "Missing attribute 'component_id' in component '#{ modifier_el.to_xml}'" 
      end
      
      component = _get_resource(resource_uri, modifier_el, opts)
      unless (cid = component.component_id).to_s == cid_attr
        raise BadRequestException.new "Wrong 'component_id'. Expected '#{cid}', but got '#{cid_attr}'"
      end
      component.update_from_xml(modifier_el, opts)
      component.save
      component
    end
    
    
    # Remove all resources from this sliver
    #
    def empty_group(group, opts)
      # unlink all resources from this group
      group.empty_group
    end
    
    # Return the state of ALL resources in this group
    #
    def show_resource(group, opts)
      path = opts[:req].path
      if group.respond_to? :to_sfa_hash
        prefix = path.split('/')[0 .. -2].join('/') + '/'
        res = group.to_sfa_hash({}, :href_prefix => prefix)
      else
        res = {}
        group.to_hash(res)
      end
      res[:about] = path
      {:group_response => res}
    end 

  end
end
    