

require 'nokogiri'
require 'uuid'
require 'set'
require 'json'
require 'thin/async'
require 'cgi'

require 'omf_base/lobject'


module OMF::SFA::AM::Rest

  class RackException < Exception
    attr_reader :reply

    def initialize(err_code, reason)
      super reason
      body = {:exception => {
        :code => err_code,
        :reason => reason
      }}
      @reply = [err_code, {"Content-Type" => 'text/json'}, body.to_json]
    end

  end

  class BadRequestException < RackException
    def initialize(reason)
      super 400, reason
    end
  end

  class EmptyBodyException < RackException
    def initialize()
      super 400, "Message body is empty"
    end
  end

  class UnsupportedBodyFormatException < RackException
    def initialize(format = 'unknown')
      super 400, "Message body format '#{format}' is unsupported"
    end
  end


  class NotAuthorizedException < RackException
    def initialize(reason)
      super 401, reason
    end
  end

  class IllegalMethodException < RackException
    def initialize(reason)
      super 403, reason
    end
  end

  class UnsupportedMethodException < RackException
    def initialize(method_name = nil, class_name = nil)
      super 403, "Unsupported Method '#{class_name || 'Unknown'}::#{method_name || 'Unknown'}'"
    end
  end

  class UnknownResourceException < RackException
    def initialize(reason)
      super 404, reason
    end
  end

  class MissingResourceException < RackException
    def initialize(reason)
      super 404, reason
    end
  end

  class TemporaryUnavailableException < RackException
    def initialize()
      super 504, "Upstream servers haven't responded yet, please try again a bit later"
    end
  end

  class RedirectException < Exception
    attr_reader :path

    def initialize(path)
      @path = path
    end
  end

  # class PromiseUnresolvedException < Exception
  #   attr_reader :uuid, :promise
  #
  #   def initialize(promise)
  #     @uuid = UUIDTools::UUID.random_create
  #     @promise = promise
  #   end
  # end

  # Raised when a request triggers an async call whose
  # result we need before answering the request
  #
  class RetryLaterException < Exception
    attr_reader :delay

    def initialize(delay = 10)
      @delay = delay
    end
  end

  # class FoundUnresolvedPromiseException < Exception
  #   attr_reader :promise
  #
  #   def initialize(promise)
  #     @promise = promise
  #   end
  # end



  class RestHandler < OMF::Base::LObject
    @@service_name = nil
    @@html_template =  File::read(File.dirname(__FILE__) + '/api_template.html')

    def self.set_service_name(name)
      @@service_name = name
    end

    def self.service_name()
      @@service_name || "Unknown Service"
    end

    def self.load_api_template(fname)
      @@html_template =  File::read(fname)
    end

    def self.render_html(parts)
      self.new().render_html(parts)
    end

    # Parse format of 'resource_uri' and (re)turn into a
    # description hash (optionally provided).
    #
    def self.parse_resource_uri(resource_uri, description = {})
      if UUID.validate(resource_uri)
        description[:uuid] = resource_uri
      elsif resource_uri.start_with? 'urn:'
        description[:urn] = resource_uri
      else
        description[:name] = resource_uri
      end
      description
    end

    def initialize(opts = {})
      @opts = opts
    end

    def call(env)
      begin
        Thread.current[:http_host] = env["HTTP_HOST"]
        req = ::Rack::Request.new(env)
        headers = {
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers' => 'origin, x-csrftoken, content-type, accept'
        }
        if req.request_method == 'OPTIONS'
          return [200 , headers, ""]
        end
        content_type, body = dispatch(req)
        #puts "BODY(#{body.class}) - #{content_type}) >>>>> #{body}"
        if body.is_a? Thin::AsyncResponse
          return body.finish
        end
        content_type, body  = _format_body(body, content_type, req, env)
        # if req['_format'] == 'html'
        #   #body = self.class.convert_to_html(body, env, Set.new((@coll_handlers || {}).keys))
        #   body = convert_to_html(body, env, {}, Set.new((@coll_handlers || {}).keys))
        #   content_type = 'text/html'
        # elsif content_type == 'application/json'
        #   body = JSON.pretty_generate(body)
        # end
        #return [200 ,{'Content-Type' => content_type}, body + "\n"]
        headers['Content-Type'] = content_type
        return [200 , headers, (body || '') + "\n"]
      rescue RackException => rex
        unless rex.is_a? TemporaryUnavailableException
          info "Caught #{rex}"
          debug rex.backtrace.join("\n")
        end
        return rex.reply
      rescue OMF::SFA::Util::PromiseUnresolvedException => pex
        uuid = 1 #pex.uuid
        path = "/promises/#{uuid}"
        require 'omf-sfa/am/am-rest/promise_handler' # delay loading as PromiseHandler sub classes this class
        OMF::SFA::AM::Rest::PromiseHandler.register_promise(pex.promise,
                                                            uuid,
                                                            req['_format'] == 'html',
                                                            Set.new((@coll_handlers || {}).keys))
        debug "Redirecting to #{path}"
        return [302, {'Location' => path}, ['Promised, but not ready yet.']]
      rescue OMF::SFA::AM::Rest::RedirectException => rex
        debug "Redirecting to #{rex.path}"
        return [302, {'Location' => rex.path}, ['Next window, please.']]

      # rescue OMF::SFA::AM::AMManagerException => aex
        # return RackException.new(400, aex.to_s).reply
      # rescue RetryLaterException => rex
      #   body = {
      #     type: 'retry',
      #     delay: rex.delay,
      #     request_id: Thread.current[:request_context_id] || 'unknown'
      #   }
      #   debug "Retry later request - #{req.url}"
      #   if req['_format'] == 'html'
      #     refresh = rex.delay.to_s
      #     if (req_id = Thread.current[:request_context_id])
      #       refresh += "; url=#{req.url}&_request_id=#{req_id}"
      #     end
      #     headers['Refresh'] = refresh # 10; url=
      #     headers['X-Request-ID'] = req_id
      #     opts = {} #{html_header: "<META HTTP-EQUIV='refresh' CONTENT='#{rex.delay}'>"}
      #     body = convert_to_html(body, env, opts)
      #     return [200 , headers, body + "\n"]
      #   end
      #   headers['Content-Type'] = 'application/json'
      #   return [504, headers, JSON.pretty_generate(body)]

      rescue Exception => ex
        body = {
          type: 'error',
          error: {
            reason: ex.to_s,
            bt: ex.backtrace #.select {|l| !l.start_with?('/') }
          }
        }
        warn "ERROR: #{ex}"
        debug ex.backtrace.join("\n")
        headers['Content-Type'] = 'application/json'
        return [500, headers, JSON.pretty_generate(body)]
      end
    end

    def _format_body(body, content_type, req, env, proxy_promise = nil)
      begin
        if req['_format'] == 'html'
          #body = self.class.convert_to_html(body, env, Set.new((@coll_handlers || {}).keys))
          content_type = 'text/html'
          body = convert_to_html(body, env, {}, Set.new((@coll_handlers || {}).keys))
        elsif content_type == 'application/json'
          body = JSON.pretty_generate(body)
        end
        [content_type, body]
      rescue OMF::SFA::Util::PromiseUnresolvedException => pex
        proxy = OMF::SFA::Util::Promise.new
        pex.promise.on_success do |d|
          proxy.resolve [content_type, body]
        end.on_error(proxy).on_progress(proxy)
        raise OMF::SFA::Util::PromiseUnresolvedException.new proxy
      end
    end

    # def _x(promise, req)
    #   uuid = 1 #pex.uuid
    #   path = "/promises/#{uuid}"
    #   require 'omf-sfa/am/am-rest/promise_handler' # delay loading as PromiseHandler sub classes this class
    #   OMF::SFA::AM::Rest::PromiseHandler.register_promise(promise,
    #                                                       uuid,
    #                                                       req['_format'] == 'html',
    #                                                       Set.new((@coll_handlers || {}).keys))
    #   debug "Redirecting to #{path}"
    #   return [302, {'Location' => path}, ['Promised, but not ready yet.']]
    # end

    def on_get(resource_uri, opts)
      debug 'get: resource_uri: "', resource_uri, '"'
      if resource_uri
        resource = opts[:resource]
        show_resource_status(resource, opts)
      else
        show_resource_list(opts)
      end
    end

    def on_put(resource_uri, opts)
      debug '>>> PUT NOT IMPLEMENTED'
      raise UnsupportedMethodException.new('on_put', @resource_class)
    end

    def on_post(resource_uri, opts)
      #debug 'POST: resource_uri "', resource_uri, '" - ', opts.inspect
      description, format = parse_body(opts, [:json, :form])
      #debug 'POST(', resource_uri, '): body(', format, '): "', description, '"'

      if resource = opts[:resource]
        debug 'POST: Modify ', resource, ' --- ', resource.class
        resource = modify_resource(resource, description, opts)
      else
        if description.is_a? Array
          resources = description.map do |d|
            debug 'POST: Create? ', d
            create_resource(d, opts)
          end
          return show_resources(resources, nil, opts)
        else
          debug 'POST: Create ', resource_uri
          # if resource_uri
            # if UUID.validate(resource_uri)
              # description[:uuid] = resource_uri
            # else
              # description[:name] = resource_uri
            # end
          # end
          resource = create_resource(description, opts, resource_uri)
        end
      end

      if resource
        show_resource_status(resource, opts)
      elsif context = opts[:context]
        show_resource_status(context, opts)
      else
        raise "Report me. Should never get here"
      end
    end

    def on_delete(resource_uri, opts)
      res = ['application/json', {}]
      if resource = opts[:resource]
        if (context = opts[:context])
          remove_resource_from_context(resource, context)
          res = show_resource_status(resource, opts)
        else
          debug "Delete resource #{resource}"
          res = show_deleted_resource(resource.uuid)
          resource.destroy
        end
      else
        res = on_delete_all(opts) || res
      end
      res
    end

    def on_delete_all(opts)
      # Delete ALL resources of this type
      raise OMF::SFA::AM::Rest::BadRequestException.new "I'm sorry, Dave. I'm afraid I can't do that."
    end

    def find_handler(path, opts)
      #debug "find_handler: path; '#{path}' opts: #{opts}"
      debug "find_handler: path: '#{path}'"
      rid = path.shift
      resource_id = opts[:resource_uri] = (rid ? URI.decode(rid) : nil) # make sure we get rid of any URI encoding
      opts[:resource] = nil
      if resource_id
        resource = opts[:resource] = find_resource(resource_id, {}, opts)
      end
      return self if path.empty?

      raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource '#{resource_id}'." unless resource
      opts[:context] = resource
      opts[:contexts][opts[:context_name].to_sym] = resource
      comp = path.shift
      if (handler = @coll_handlers[comp.to_sym])
        opts[:context_name] = comp
        opts[:resource_uri] = URI.decode(path.join('/'))
        if handler.is_a? Proc
          return handler.call(path, opts)
        end
        return handler.find_handler(path, opts)
      end
      raise UnknownResourceException.new "Unknown sub collection '#{comp}' for '#{resource_id}:#{resource.class}'."
    end


    protected

    def modify_resource(resource, description, opts)
      if description[:uuid]
        raise "Can't change uuid" unless  description[:uuid] == resource.uuid.to_s
      end
      description.delete(:href)
      resource.update(description) ? resource : nil
      resource
    end


    def create_resource(description, opts, resource_uri = nil)
      debug "Create: uri: '#{resource_uri.inspect}' class: #{description.class}--#{description}"

      query = {}
      unless (resource_uri || '').empty?
        query = self.class.parse_resource_uri(resource_uri, query)
        description.merge!(query)
      else
        [:uuid, :urn, :name].each do |k|
          if v = description[k]
            query[k] = v
          end
        end
      end

      # Let's find if the resource already exists. If yes, just modify it
      # if description[:uuid] || descri
        # debug 'Trying to find resource ', uuid, "'"
        # resource = @resource_class.first(uuid: uuid)
      # end
      unless query.empty?
        debug 'Trying to find "', @resource_class, '" ', query, "'"
        resource = @resource_class.first(query)
      end
      if resource
        modify_resource(resource, description, opts)
      else
        debug 'Trying to create resource ', @resource_class, ' - ', description
        resource = _really_create_resource(description, opts)
        on_new_resource(resource)
      end
      if (context = opts[:context])
        add_resource_to_context(resource, context)
      end
      return resource
    end

    def _really_create_resource(description, opts)
      @resource_class.create(description)
    end

    # Parse format of 'resource_uri' and (re)turn into a
    # description hash (optionally provided).
    #
    def _parse_resource_uri(resource_uri, description = {})
      if UUID.validate(resource_uri)
        description[:uuid] = resource_uri
      elsif resource_uri.start_with? 'urn:'
        description[:urn] = resource_uri
      else
        description[:name] = resource_uri
      end
      description
    end


    # Can be used to further customize a newly created
    # resource.
    #
    def on_new_resource(resource)
      debug "Created: #{resource}"
    end

    def add_resource_to_context(resource, context)
      raise UnsupportedMethodException.new(:add_resource_to_context, self.class)
    end

    def remove_resource_from_context(resource, context)
      raise UnsupportedMethodException.new(:remove_resource_from_context, self.class)
    end


    # Extract information from the request object and
    # store them in +opts+.
    #
    # Extract information from the request object and
    # store them in +opts+.
    #
    def populate_opts(req, opts)
      opts[:req] = req
      opts[:context_name] = (req.env['REQUEST_PATH'].split('/') - req.path_info.split('/'))[-1]
      opts[:contexts] ||= {}
      path = req.path_info.split('/').select { |p| !p.empty? }
      opts[:target] = find_handler(path, opts)
      rl = req.params.delete('_level')
      opts[:max_level] = rl ? rl.to_i : 0
      #opts[:target].inspect
      opts
    end

    # Return a named context resource. If it is a promise and not yet
    # available, a TemporaryUnavailableException is being thrown.
    #
    # For instance if we have a path /users/xxx/friends/yyy/favorites
    # by the time we get to the 'favorites' handler, we can access
    # the respective 'users', 'friends' object through this method.
    # PLEASE note the plurals 'users', 'friends'.
    #
    def get_context_resource(name, opts)
      resource = opts[:contexts][name]
      if resource.is_a? OMF::SFA::Util::Promise
        resource = resource.value(OMF::SFA::AM::Rest::TemporaryUnavailableException)
      end
      resource
    end

    def parse_body(opts, allowed_formats = [:json, :xml])
      req = opts[:req]
      body = req.body #req.POST
      raise EmptyBodyException.new unless body
      if body.is_a? Hash
        raise UnsupportedBodyFormatException.new('Send body raw, not as form data')
      end
      (body = body.string) if body.is_a? StringIO
      #debug 'PARSE_BODY(ct: ', req.content_type, '): ', body.inspect
      unless content_type = req.content_type
        body.strip!
        if ['/', '{', '['].include?(body[0])
          content_type = 'application/json'
        else
          if body.empty?
            params = req.params.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
            if allowed_formats.include?(:json)
              return [params, :json]
            elsif allowed_formats.include?(:form)
              return [params, :form]
            end
          end
          # default is XML
          content_type = 'text/xml'
        end
      end
      begin
        case content_type
        when 'application/json'
          raise UnsupportedBodyFormatException.new(:json) unless allowed_formats.include?(:json)
          jb = JSON.parse(body)
          return [_rec_sym_keys(jb), :json]
        when 'text/xml'
          xb = Nokogiri::XML(body)
          raise UnsupportedBodyFormatException.new(:xml) unless allowed_formats.include?(:xml)
          return [xb, :xml]
        when 'application/x-www-form-urlencoded'
          raise UnsupportedBodyFormatException.new(:xml) unless allowed_formats.include?(:form)
          fb = req.POST
          #puts "FORM: #{fb.inspect}"
          return [fb, :form]
        end
      rescue Exception => ex
        raise BadRequestException.new "Problems parsing body (#{ex})"
      end
      raise UnsupportedBodyFormatException.new(content_type)
    end

    private
    # Don't override


    def dispatch(req)
      opts = {}
      populate_opts(req, opts)
      #opts[:req] = req
      #puts "OPTS>>>> #{opts.inspect}"
      method = req.request_method
      target = opts[:target] #|| self
      resource_uri = opts[:resource_uri]
      _dispatch(method, target, resource_uri, opts)
    end

    def _dispatch(method, target, resource_uri, opts)
      case method
      when 'GET'
        res = target.on_get(resource_uri, opts)
      when 'PUT'
        res = target.on_put(resource_uri, opts)
      when 'POST'
        res = target.on_post(resource_uri, opts)
      when 'DELETE'
        res = target.on_delete(resource_uri, opts)
      else
        raise IllegalMethodException.new method
      end
    end

    def show_resource_status(resource, opts)
      if resource
        resource = resolve_promise(resource) do |r|
          show_resource_status(r, opts)
        end
        about = opts[:req].path
        refresh = ['', '1', 't', 'T', 'true', 'TRUE'].include?(opts[:req].params['_refresh'])
        props = resource.to_hash({}, max_level: opts[:max_level], refresh: refresh)
        props.delete(:type)
        res = after_resource_to_hash_hook({
          #:about => about,
          :type => resource.resource_type,
        }.merge!(props))
      else
        res = {:error => 'Unknown resource'}
      end
      check_for_promises 'application/json', res
    end

    def after_resource_to_hash_hook(res_hash)
      res_hash
    end

    def absolute_path(rel_path)
      "http://#{Thread.current[:http_host]}#{rel_path.start_with?('/') ? '' : '/'}#{rel_path}"
    end

    def find_resource(resource_uri, description = {}, opts = {})
      descr = description.dup
      descr.delete(:resource_uri)
      if UUID.validate(resource_uri)
        descr[:uuid] = resource_uri
      elsif resource_uri.start_with?('urn')
        descr[:urn] = resource_uri
      else
        descr[:name] = resource_uri
      end

      #authenticator = Thread.current["authenticator"]
      descr = _find_resource_before_hook(descr, opts)
      debug "Finding #{@resource_class}.first(#{descr})"
      @resource_class.first(descr)
    end

    # Allow sub class to override search criteria for resource
    def _find_resource_before_hook(descr, opts)
      descr
    end

    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      if (context = opts[:context])
        resources = context.send(opts[:context_name].to_sym)
      else
        resources = @resource_class.all()
      end
      show_resources(resources, nil, opts)
    end

    def show_resources(resources, resource_name, opts)
      resources = resolve_promise(resources) do |r|
        show_resources(r, resource_name, opts)
      end
      #hopts = {max_level: opts[:max_level], level: 1}
      hopts = {max_level: opts[:max_level], level: 0}
      objs = {}
      res_hash = resources.map do |a|
        a = resolve_promise(a) do |r|
          # The resolved promise was embeded, so we need to start afresh from the top
          show_resources(resources, resource_name, opts)
        end
        next unless a # TODO: This seems to be a bug in OProperty (removing objects)
        a.to_hash(objs, hopts)
        #a.to_hash_brief(:href_use_class_prefix => true)
      end.compact
      if resource_name
        prefix = about = opts[:req].path
        res = {
          #:about => opts[:req].path,
          resource_name => res_hash
        }
      else
        res = res_hash
      end
      check_for_promises 'application/json', res
    end

    # Check if 'value' is a promise. If not, return it immediately. If it is
    # a promise, return it's value if it has been already resolved. Otherwise
    # throw a PromiseDeferException. If the promise gets resolved at some later
    # stage the 'block' is called and is expected to return the same result as
    # the caller of this function would have returned if this function would have
    # returned immediately.
    #
    def resolve_promise(value, &block)
      if (promise = value).is_a? OMF::SFA::Util::Promise
        case promise.status
        when :pending
          proxy = OMF::SFA::Util::Promise.new
          promise.on_success do |d|
            proxy.resolve block.call(d)
          end.on_error(proxy).on_progress(proxy)
          raise OMF::SFA::Util::PromiseUnresolvedException.new proxy
        when :rejected
          raise promise.error_msg
        else
          value = promise.value
        end
      end
      #puts "RESOLVE PROMISE(#{value.class}>>> #{value}"
      value
    end

    # Check if any elements in res, which is either an array
    # or hash, is a promise. If one is found, and can't be resolved,
    # a PromiseDeferException is thrown. The proxy promise in the exception
    # will monitor the unresolved promises and after all of them are resolved
    # will resolve the associated promise with a 'clean' res.
    #
    def check_for_promises(mime_type, res, proxy = nil)
      begin
        res = _scan_for_promises(res)
      rescue OMF::SFA::Util::PromiseUnresolvedException => pex
        unless proxy
          proxy = OMF::SFA::Util::Promise.new
          pex.promise.on_success do |x|
            check_for_promises(mime_type, res, proxy)
          end.on_error do |ec, em|
            proxy.reject(ec, em)
          end.on_progress(proxy)
          raise OMF::SFA::Util::PromiseUnresolvedException.new proxy
        end
      end
      if proxy
        proxy.resolve [mime_type, res]
      end
      [mime_type, res]
    end

    def _scan_for_promises(res)
      if res.is_a? Array
        res = res.map do |el|
          _scan_for_promises(el)
        end
      elsif res.is_a? Hash
        res.each do |key, val|
          res[key] = _scan_for_promises(val)
        end
      elsif res.is_a? OMF::SFA::Util::Promise
        case res.status
        when :resolved
          return res.value
        when :rejected
          raise res.err_message
        else
          raise OMF::SFA::Util::PromiseUnresolvedException.new(res)
        end
      end
      res # seems to be 'normal' value
    end


    def show_deleted_resource(uuid)
      res = {
        uuid: uuid,
        deleted: true
      }
      ['application/json', res]
    end

    def show_deleted_resources(uuid_a)
      res = {
        uuids: uuid_a,
        deleted: true
      }
      ['application/json', res]
    end

    # Recursively Symbolize keys of hash
    #
    def _rec_sym_keys(array_or_hash)
      if array_or_hash.is_a? Array
        return array_or_hash.map {|e| e.is_a?(Hash) ? _rec_sym_keys(e) : e }
      end

      h = {}
      array_or_hash.each do |k, v|
        if v.is_a? Hash
          v = _rec_sym_keys(v)
        elsif v.is_a? Array
          v = v.map {|e| e.is_a?(Hash) ? _rec_sym_keys(e) : e }
        end
        h[k.to_sym] = v
      end
      h
    end

    public

    # Render an HTML page using the resource's template. The
    # template is populated with information provided in 'parts'
    #
    # * :header - HTML header additions
    # * :title - HTML title
    # * :service - Service path (usually a set of <a>)
    # * :content - Main content
    # * :footer - Optional footer
    # * :result - hash or array describing the result (may used by JS to further format)
    #
    def render_html(parts = {})
      #puts "PP>> #{parts}"
      tmpl = html_template()
      if (header = parts[:header])
        tmpl = tmpl.gsub('##HEADER##', header)
      end
      if (result = parts[:result])
        tmpl = tmpl.gsub('##JS##', JSON.pretty_generate(result))
      end
      title = parts[:title] || @@service_name || "Unknown Service"
      tmpl = tmpl.gsub('##TITLE##', title)
      if (service = parts[:service])
        tmpl = tmpl.gsub('##SERVICE##', service)
      end
      if (content = parts[:content])
        tmpl = tmpl.gsub('##CONTENT##', content)
      end
      if (footer = parts[:footer])
        tmpl = tmpl.gsub('##FOOTER##', footer)
      end
      tmpl
    end

    def convert_to_html(obj, env, opts, collections = Set.new)
      req = ::Rack::Request.new(env)
      opts = {
        collections: collections,
        level: 0,
        href_prefix: "#{req.path}/",
        env: env
      }.merge(opts)

      path = req.path.split('/').select { |p| !p.empty? }
      h2 = ["<a href='/?_format=html&_level=0'>ROOT</a>"]
      path.each_with_index do |s, i|
        h2 << "<a href='/#{path[0 .. i].join('/')}?_format=html&_level=#{i % 2 ? 0 : 1}'>#{s}</a>"
      end

      res = []
      _convert_obj_to_html(obj, nil, res, opts)

      render_html(
        header: opts[:html_header] || '',
        result: obj,
        title: @@service_name || env["HTTP_HOST"],
        service: h2.join('/'),
        content: res.join("\n")
      )
    end

    def html_template()
      @@html_template
    end

    protected
    def _convert_obj_to_html(obj, ref_name, res, opts)
      klass = obj.class
      #puts "CONVERT>>>> #{ref_name} ... #{obj.class}::#{obj.to_s[0 .. 80]}"
      if obj.is_a? OMF::SFA::Util::Promise
        obj = obj.to_html()
      end
      if (obj.is_a? OMF::SFA::Resource::OPropertyArray) || obj.is_a?(Array)
        if obj.empty?
          res << '<span class="empty">empty</span>'
        else
          res << '<ul>'
          _convert_array_to_html(obj, ref_name, res, opts)
          res << '</ul>'
        end
      elsif obj.is_a? Hash
        res << '<ul>'
        _convert_hash_to_html(obj, ref_name, res, opts)
        res << '</ul>'
      else
        if obj.to_s.start_with? 'http://'
          res << _convert_link_to_html(obj)
        else
          if obj.is_a? String
            obj = CGI.escapeHTML obj
          end
          res << " <span class='value'>#{obj}</span> "
        end
      end
    end

    def _convert_array_to_html(array, ref_name, res, opts)
      opts = opts.merge(level: opts[:level] + 1, context: array)
      array.each do |obj|
        #puts "AAA>>>> #{obj}::#{opts}"
        name = nil
        if (obj.is_a? OMF::SFA::Resource::OResource)
          obj = obj.to_hash()
        end
        if obj.is_a? Hash
          if name = obj[:name] || obj[:uuid]
            res << "<li><span class='key'>#{_convert_link_to_html obj[:href], name}:</span>"
          else
            res << "<li>#{_convert_link_to_html obj['href']}:"
          end
        else
          res << '<li>'
        end
        _convert_obj_to_html(obj, ref_name, res, opts)
        res << '</li>'
      end
    end

    def _convert_hash_to_html(hash, ref_name, res, opts)
      #puts ">>>> #{hash}::#{opts}"
      opts = opts.merge(context: hash)
      hash.each do |key, obj|
        #key = "#{key}-#{opts[:level]}-#{opts[:collections].to_a.inspect}"
        if opts[:level] == 0 && opts[:collections].include?(key.to_sym)
          key = _convert_link_to_html "#{opts[:href_prefix]}#{key}", key
        end
        res << "<li><span class='key'>#{key}:</span>"
        _convert_obj_to_html(obj, key, res, opts)
        res << '</li>'
      end
    end

    def _convert_link_to_html(href, text = nil)
      h = href.is_a?(URI) ? href.to_s : "#{href}?_format=html&_level=1"
      "<a href='#{h}'>#{text || href}</a>"
    end

  end

end

