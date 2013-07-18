
require 'omf-sfa/am/am-rest/rest_handler'

module OMF::SFA::AM::Rest

  # Handles an individual resource
  #
  class ResourceHandler < RestHandler

    def initialize(opts = {})
      super
      @resource_class = OMF::SFA::Resource::OComponent
      # Define handlers
      opts[:resource_handler] = self
      # @coll_handlers = {
        # projects: (opts[:project_handler] || ProjectHandler.new(opts))
      # }
    end
    # SUPPORTING FUNCTIONS

    def show_resource_list(opts)
      authenticator = Thread.current["authenticator"]
      prefix = about = opts[:req].path
      # if project = opts[:context]
        # users = project.users
      # else
        resources = OMF::SFA::Resource::OComponent.all()
      # end
      show_resources(resources, :resources, opts)
    end

    # def remove_resource_from_context(user, context)
      # debug "REMOVE #{user} from #{context}"
      # context.users.delete(user)
      # context.save
    # end
#
    # def add_resource_to_context(user, context)
      # debug "ADD #{user} to #{context}"
      # context.users << user
      # context.save
    # end

    # # Return the handler responsible for requests to +path+.
    # # The default is 'self', but override if someone else
    # # should take care of it
    # #
    # def find_handler(path, opts)
      # #opts[:account] = @am_manager.get_default_account
      # opts[:resource_uri] = path.join('/')
      # debug "find_handler: path: '#{path}' opts: '#{opts.inspect}'"
      # self
    # end
#
#
    # def on_get(resource_uri, opts)
      # authenticator = Thread.current["authenticator"]
      # unless resource_uri.empty?
        # opts[:path] = opts[:req].path.split('/')[0 .. -2].join('/')
        # resource = @am_manager.find_resource(resource_uri, authenticator)
      # else
        # resource = @am_manager.find_all_resources_for_account(opts[:account], authenticator)
      # end
      # show_resource(resource, opts)
    # end
#
    # def on_put(resource_uri, opts)
      # resource = update_resource(resource_uri, true, opts)
      # show_resource(resource, opts)
    # end
#
    # def on_post(resource_uri, opts)
      # resource = update_resource(resource_uri, false, opts)
      # show_resource(resource, opts)
    # end
#
    # def on_delete(resource_uri, opts)
      # delete_resource(resource_uri, opts)
      # show_resource(nil, opts)
    # end
#
#
    # # Update resource(s) referred to by +resource_uri+. If +clean_state+ is
    # # true, reset any other state to it's default.
    # #
    # def update_resource(resource_uri, clean_state, opts)
      # body, format = parse_body(opts)
      # case format
      # # when :empty
        # # # do nothing
      # when :xml
        # puts ">>>>> #{body.inspect}"
        # resource = @am_manager.update_resources_from_xml(body.root, clean_state, opts)
      # else
        # raise UnsupportedBodyFormatException.new(format)
      # end
      # resource
    # end
#
#
    # # This methods deletes components, or more broadly defined, removes them
    # # from a slice.
    # #
    # # Currently, we simply transfer components to the +default_sliver+
    # #
    # def delete_resource(resource_uri, opts)
      # @am_manager.delete_resource(resource_uri, opts)
    # end
#
    # # Update the state of +component+ according to inforamtion
    # # in the http +req+.
    # #
    # #
    # def update_component_xml(component, modifier_el, opts)
    # end
#
    # # Return the state of +component+
    # #
    # # +component+ - Component to display information about. !!! Can be nil - show only envelope
    # #
    # def show_resource(resource, opts)
      # unless about = opts[:req].path
        # throw "Missing 'path' declaration in request"
      # end
      # path = opts[:path] || about
#
      # case opts[:format]
      # when 'xml'
        # show_resources_xml(resource, path, opts)
      # else
        # show_resources_json(resource, path, opts)
      # end
    # end
#
    # def show_resources_xml(resource, path, opts)
      # #debug "show_resources_xml: #{resource}"
      # opts[:href_prefix] = path
      # announcement = OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resource, opts)
      # ['text/xml', announcement.to_xml]
    # end
#
    # def show_resources_json(resources, path, opts)
      # res = resources ? resource_to_json(resources, path, opts) : {}
      # res[:about] = opts[:req].path
#
      # ['application/json', JSON.pretty_generate({:resource_response => res}, :for_rest => true)]
    # end
#
    # def resource_to_json(resource, path, opts, already_described = {})
      # debug "resource_to_json: resource: #{resource}, path: #{path}"
      # if resource.kind_of? Enumerable
        # res = []
        # resource.each do |r|
          # p = path
          # res << resource_to_json(r, p, opts, already_described)[:resource]
        # end
        # res = {:resources => res}
      # else
        # #prefix = path.split('/')[0 .. -2].join('/') # + '/'
        # prefix = path
        # if resource.respond_to? :to_sfa_hashXXX
          # debug "TO_SFA_HASH: #{resource}"
          # res = {:resource => resource.to_sfa_hash(already_described, :href_prefix => prefix)}
        # else
          # rh = resource.to_hash(already_described, opts.merge(:href_prefix => prefix))
          # # unless (account = resource.account) == @am_manager.get_default_account()
            # # rh[:account] = {:uuid => account.uuid.to_s, :name => account.name}
          # # end
          # res = {:resource => rh}
        # end
      # end
      # res
    # end

    protected

  end # ResourceHandler
end # module