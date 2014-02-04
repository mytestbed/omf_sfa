

require 'nokogiri'
require 'uuid'
require 'set'
require 'json'

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
    def initialize()
      super 403, "Unsupported Method"
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

  class RedirectException < Exception
    attr_reader :path

    def initialize(path)
      @path = path
    end
  end


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


    def initialize(opts = {})
      @opts = opts
    end

    def call(env)
      begin
        Thread.current[:http_host] = env["HTTP_HOST"]
        req = ::Rack::Request.new(env)
        if req.request_method == 'OPTIONS'
          return [200 ,{
            'Access-Control-Allow-Origin' => '*' ,
            'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers' => 'origin, x-csrftoken, content-type, accept'
          }, ""]
        end
        content_type, body = dispatch(req)
<<<<<<< HEAD
        #return [200 ,{'Content-Type' => 'application/json'}, JSON.pretty_generate(body)]
        return [200 ,{ 'Content-Type' => content_type, 'Access-Control-Allow-Origin' => '*' , 'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS' }, body + "\n"]
=======
        if req['_format'] == 'html'
          #body = self.class.convert_to_html(body, env, Set.new((@coll_handlers || {}).keys))
          body = convert_to_html(body, env, {}, Set.new((@coll_handlers || {}).keys))
          content_type = 'text/html'
        elsif content_type == 'application/json'
          body = JSON.pretty_generate(body)
        end
        return [200 ,{'Content-Type' => content_type}, body + "\n"]
>>>>>>> ch_exploration
      rescue RackException => rex
        return rex.reply
      rescue RedirectException => rex
        debug "Redirecting to #{rex.path}"
        return [301, {'Location' => rex.path, "Content-Type" => ""}, ['Next window!']]
      # rescue OMF::SFA::AM::AMManagerException => aex
        # return RackException.new(400, aex.to_s).reply
      rescue Exception => ex
        body = {
          :error => {
            :reason => ex.to_s,
            :bt => ex.backtrace #.select {|l| !l.start_with?('/') }
          }
        }
        warn "ERROR: #{ex}"
        debug ex.backtrace.join("\n")
<<<<<<< HEAD
        # root = _create_response('error', req = nil)
        # doc = root.document
        # reason = root.add_child(Nokogiri::XML::Element.new('reason', doc))
        # reason.content = ex.to_s
        # reason = root.add_child(Nokogiri::XML::Element.new('bt', doc))
        # reason.content = ex.backtrace.join("\n\t")
        return [500, { "Content-Type" => 'application/json', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS' }, JSON.pretty_generate(body)]
=======
        return [500, {"Content-Type" => 'application/json'}, body]
>>>>>>> ch_exploration
      end
    end

    def on_get(resource_uri, opts)
      debug 'get: resource_uri: "', resource_uri, '"'
      if resource_uri
        resource = opts[:resource]
        show_resource_status(resource, opts)
      else
        show_resource_list(opts)
      end
    end

    def on_post(resource_uri, opts)
      #debug 'POST: resource_uri "', resource_uri, '" - ', opts.inspect
      description, format = parse_body(opts, [:json, :form])
      debug 'POST(', resource_uri, '): body(', format, '): "', description, '"'

      if resource = opts[:resource]
        debug 'POST: Modify ', resource
        modify_resource(resource, description, opts)
      else
        debug 'POST: Create? ', description.class
        if description.is_a? Array
          resources = description.map do |d|
            create_resource(d, opts)
          end
          return show_resources(resources, nil, opts)
        else
          debug 'POST: Create ', resource_uri
          if resource_uri
            if UUID.validate(resource_uri)
              description[:uuid] = resource_uri
            else
              description[:name] = resource_uri
            end
          end
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
        # Delete ALL resources of this type
        raise OMF::SFA::AM::Rest::BadRequestException.new "I'm sorry, Dave. I'm afraid I can't do that."
      end
      resource.reload
      return res
    end


    def find_handler(path, opts)
      debug "find_handler: path; '#{path}' opts: #{opts}"
      resource_id = opts[:resource_uri] = path.shift
      opts[:resource] = nil
      if resource_id
        resource = opts[:resource] = find_resource(resource_id)
      end
      return self if path.empty?

      raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource '#{resource_id}'." unless resource
      opts[:context] = resource
      comp = path.shift
      if (handler = @coll_handlers[comp.to_sym])
        opts[:resource_uri] = path.join('/')
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
      #raise UnsupportedMethodException.new
    end


    def create_resource(description, opts, resource_uri = nil)
      debug "Create: #{description.class}--#{description}"

      if resource_uri
        if UUID.validate(resource_uri)
          description[:uuid] = resource_uri
        else
          description[:name] = resource_uri
        end
      end

      # Let's find if the resource already exists. If yes, just modify it
      if uuid = description[:uuid]
        debug 'Trying to find resource ', uuid, "'"
        resource = @resource_class.first(uuid: uuid)
      end
      if resource
        modify_resource(resource, description, opts)
      else
        resource = @resource_class.create(description)
        debug "Created: #{resource}"
      end
      if (context = opts[:context])
        add_resource_to_context(resource, context)
      end
      return resource
    end

    def add_resource_to_context(user, context)
      raise UnsupportedMethodException.new
    end

    def remove_resource_from_context(user, context)
      raise UnsupportedMethodException.new
    end


    # Extract information from the request object and
    # store them in +opts+.
    #
    # Extract information from the request object and
    # store them in +opts+.
    #
    def populate_opts(req, opts)
      path = req.path_info.split('/').select { |p| !p.empty? }
      opts[:target] = find_handler(path, opts)
      rl = req.params.delete('_level')
      opts[:max_level] = rl ? rl.to_i : 0
      #opts[:target].inspect
      opts
    end

    def parse_body(opts, allowed_formats = [:json, :xml])
      req = opts[:req]
      body = req.body #req.POST
      raise EmptyBodyException.new unless body
      if body.is_a? Hash
        raise UnsupportedBodyFormatException.new('Send body raw, not as form data')
      end
      (body = body.string) if body.is_a? StringIO
      debug 'PARSE_BODY(ct: ', req.content_type, '): ', body.inspect
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
      opts[:req] = req
      #puts "OPTS>>>> #{opts.inspect}"
      method = req.request_method
      target = opts[:target] #|| self
      resource_uri = opts[:resource_uri]
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
        about = opts[:req].path
        props = resource.to_hash({}, :max_level => opts[:max_level])
        props.delete(:type)
        res = {
          #:about => about,
          :type => resource.resource_type,
        }.merge!(props)
      else
        res = {:error => 'Unknown resource'}
      end

      ['application/json', res]
    end




    def find_resource(resource_uri, description = {})
      descr = description.dup
      descr.delete(:resource_uri)
      if UUID.validate(resource_uri)
        descr[:uuid] = resource_uri
      else
        descr[:name] = resource_uri
      end
      if resource_uri.start_with?('urn')
        descr[:urn] = resource_uri
      end
      #authenticator = Thread.current["authenticator"]
      debug "Finding #{@resource_class}.first(#{descr})"
      @resource_class.first(descr)
    end

    def show_resource_list(opts)
      # authenticator = Thread.current["authenticator"]
      resources = @resource_class.all()
      show_resources(resources, nil, opts)
    end

    def show_resources(resources, resource_name, opts)
      #hopts = {max_level: opts[:max_level], level: 1}
      hopts = {max_level: opts[:max_level], level: 0}
      objs = {}
      res_hash = resources.map do |a|
        a.to_hash(objs, hopts)
        #a.to_hash_brief(:href_use_class_prefix => true)
      end
      if resource_name
        prefix = about = opts[:req].path
        res = {
          #:about => opts[:req].path,
          resource_name => res_hash
        }
      else
        res = res_hash
      end
      ['application/json', res]
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
    # * :title - HTML title
    # * :service - Service path (usually a set of <a>)
    # * :content - Main content
    # * :footer - Optional footer
    # * :result - hash or array describing the result (may used by JS to further format)
    #
    def render_html(parts = {})
      #puts "PP>> #{parts}"
      tmpl = html_template()
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

    def convert_to_html(body, env, opts, collections = Set.new)
      req = ::Rack::Request.new(env)
      opts = {
        collections: collections,
        level: 0,
        href_prefix: "#{req.path}/"
      }.merge(opts)

      path = req.path.split('/').select { |p| !p.empty? }
      h2 = ["<a href='/?_format=html&_level=0'>ROOT</a>"]
      path.each_with_index do |s, i|
        h2 << "<a href='/#{path[0 .. i].join('/')}?_format=html&_level=#{i % 2 ? 0 : 1}'>#{s}</a>"
      end

      res = []
      _convert_obj_to_html(body, nil, res, opts)

      render_html(
        result: body,
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
      #puts "CONVERT>>>> #{obj.class}::#{obj}"
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
          res << " <span class='value'>#{obj}</span> "
        end
      end
    end

    def _convert_array_to_html(array, ref_name, res, opts)
      opts = opts.merge(level: opts[:level] + 1)
      array.each do |obj|
        #puts "AAA>>>> #{obj}::#{opts}"
        name = nil
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

