

require 'nokogiri'

# require 'omf-sfa/resource/sliver'
# require 'omf-sfa/resource/node'
# require 'omf-sfa/resource/link'
# require 'omf-sfa/resource/interface'

require 'set'
require 'json'

require 'omf_common/lobject'
require 'omf-sfa/am/am_manager'


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


  class RestHandler < OMF::Common::LObject

    def initialize(am_manager, opts = {})
      #puts "INIT>>> #{am_manager}::#{self}"
      @am_manager = am_manager
      @opts = opts
    end

    def call(env)
      begin
        req = ::Rack::Request.new(env)
        content_type, body = dispatch(req)
        #return [200 ,{'Content-Type' => 'application/json'}, JSON.pretty_generate(body)]
        return [200 ,{'Content-Type' => content_type}, body]
      rescue RackException => rex
        return rex.reply
      rescue OMF::SFA::AM::AMManagerException => aex
        return RackException.new(400, aex.to_s).reply
      rescue Exception => ex
        body = {
          :error => {
            :reason => ex.to_s,
            :bt => ex.backtrace #.select {|l| !l.start_with?('/') }
          }
        }
        warn "ERROR: #{ex}"
        debug ex.backtrace.join("\n")
        # root = _create_response('error', req = nil)
        # doc = root.document
        # reason = root.add_child(Nokogiri::XML::Element.new('reason', doc))
        # reason.content = ex.to_s
        # reason = root.add_child(Nokogiri::XML::Element.new('bt', doc))
        # reason.content = ex.backtrace.join("\n\t")
        return [500, {"Content-Type" => 'application/json'}, JSON.pretty_generate(body)]
      end
    end

    protected


    # Extract information from the request object and
    # store them in +opts+.
    #
    # Extract information from the request object and
    # store them in +opts+.
    #
    def populate_opts(req, opts)
      path = req.path_info.split('/').select { |p| !p.empty? }
      opts[:target] = find_handler(path, opts)
      #opts[:target].inspect
      opts
    end



    def parse_body(opts, allowed_formats = [:json, :xml])
      req = opts[:req]
      post = req.POST
      raise EmptyBodyException.new unless post
      body = post.to_a[0][1]  # HACK ALERT

      puts "PARSE_BODY(#{post.class}): #{post}"
      puts "PARSE_BODY2: #{body}"
      body.strip!
      begin
        if body.start_with?('/') || body.start_with?('{') || body.start_with?('[')
          raise UnsupportedBodyFormatException.new(:json) unless allowed_formats.include?(:json)
          jb = JSON.parse(body)
          return [jb, :json]
        else
          xb = Nokogiri::XML(body)
          raise UnsupportedBodyFormatException.new(:xml) unless allowed_formats.include?(:xml)
          #puts "PARSE_BODY2: #{xb.to_s}"
          return [xb, :xml]
        end
      rescue Exception => ex
        raise BadRequestException.new "Problems parsing body (#{ex})"
      end
      raise UnsupportedBodyFormatException.new() unless allowed_formats.include?(:xml)
      #raise BadRequestException.new "Unsupported message format '#{format}'" unless format ==
    end

    private
    # Don't override


    def dispatch(req)
      opts = {}
      populate_opts(req, opts)
      opts[:req] = req
      opts[:format] = req['format'] || 'json'
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
        props = resource.to_hash({}, :href_use_class_prefix => true)
        props.delete(:type)
        res = {
          :about => about,
          :type => resource.resource_type,
        }.merge!(props)
        res = {"#{resource.resource_type}_response" => res}
      else
        res = {:error_response => {:error => 'Unknown resource'}}
      end

      ['application/json', JSON.pretty_generate(res)]
    end


    def find_resource(resource_id, resource_class)
      if resource_id.start_with?('urn')
        fopts = {:urn => resource_id}
      else
        begin
          fopts = {:uuid => UUIDTools::UUID.parse(resource_id)}
        rescue ArgumentError => ax
          fopts = {:name => resource_id}
        end
      end
      #authenticator = Thread.current["authenticator"]
      resource_class.first(fopts)
    end


    # Helper functions

    # Return relevant Sliver instance.
    #
    # +opts+ is assume to contain a ':sliver_id' entry holding the
    # sliver name. It will also store the returned sliver in
    # 'opts[sliver]'.
    #
    # If the names sliver cannot be found an +UnknownResourceException+
    # exception is raised, excpet if +raise_if_nil+ is set to false.
    #
    # @returns Sliver instance
    #
    # def _get_sliver(opts, raise_if_nil = true)
      # sliver = opts[:sliver]
      # return sliver if sliver
#
      # sliver_id = opts[:sliver_id] ||= @opts[:sliver_id]
      # sliver = OMF::SFA::Resource::Sliver.first(:name => sliver_id)
      # if raise_if_nil && sliver.nil?
        # raise UnknownResourceException.new "Sliver '#{sliver_id}' doesn't exist"
      # end
      # sliver
    # end

  end
end

