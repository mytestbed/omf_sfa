
module OMF::SFA::AM::Rest

  class PromiseHandler < RestHandler

    @@contexts = {}

    def self.register_promise(promise, uuid = nil, html_reply = false, collection_set = nil)
      debug "Registering promise '#{uuid}' - #{promise}"
      uuid ||= UUIDTools::UUID.random_create
      #uuid = 1 # TODO: REMOVE
      @@contexts[uuid.to_s] = {
        promise: promise,
        html_reply: html_reply,
        collection_set: collection_set || Set.new,
        timestamp: Time.now
      }
      path = "/promises/#{uuid}"
      debug "Redirecting to #{path}"
      return [302, {'Location' => path}, ['Promised, but not ready yet.']]
    end

    def call(env)
      begin
        req = ::Rack::Request.new(env)
        headers = {
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers' => 'origin, x-csrftoken, content-type, accept'
        }
        if req.request_method == 'OPTIONS'
          return [200 , headers, ""]
        end

        uuid = req.path_info.split('/')[-1]
        debug "Checking for promise '#{uuid}'"

        unless context = @@contexts[uuid]
          return [404, {}, "Can't find requested promise"]
        end
        context[:timestamp] = Time.now # keep reaper away
        promise = context[:promise]
        case promise.status
        when :pending
          return retry_later(req, context)
        when :rejected
          body = {
            type: 'error',
            error: {
              reason: promise.error_msg,
              code: promise.error_code
            }
          }
          headers['Content-Type'] = 'application/json'
          return [500, headers, JSON.pretty_generate(body)]
        end

        # OK, the promise seems to have been resolved
        content_type, body = promise.value
        #puts ">>>>VALUE #{body.class} - #{content_type}>>>>> #{body}"
        if body.is_a? Thin::AsyncResponse
          return body.finish
        end

        begin
          if content_type == 'text/html'
            #body = self.class.convert_to_html(body, env, Set.new((@coll_handlers || {}).keys))
            body = convert_to_html(body, env, {}, context[:collection_set])
          else
            content_type = 'application/json'
            body = JSON.pretty_generate(body)
          end
        rescue OMF::SFA::Util::PromiseUnresolvedException => pex
          proxy = OMF::SFA::Util::Promise.new
          pex.promise.on_success do |d|
            proxy.resolve [content_type, body]
          end.on_error(proxy)
          uuid = pex.uuid
          path = "/promises/#{uuid}"
          require 'omf-sfa/am/am-rest/promise_handler' # delay loading as PromiseHandler sub classes this class
          self.class.register_promise(proxy, uuid, context[:html_reply], context[:collection_set])
          debug "Redirecting to #{path}"
          return [302, {'Location' => path}, ['Promised, but not ready yet.']]
        end
        headers['Content-Type'] = content_type
        return [200 , headers, (body || '') + "\n"]

      rescue RackException => rex
        return rex.reply
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

    def retry_later(req, context)
      body = {
        type: 'retry',
        delay: 10, # rex.delay,
        url: absolute_path(req.env['REQUEST_PATH']),
        progress: context[:promise].progress.map do |ts, msg|
          "#{ts.utc.iso8601}: #{msg}"
        end
      }
      debug "Retry later request - #{req.url}"
      headers = {'Content-Type' => 'application/json'}
      return [504, headers, JSON.pretty_generate(body)]
    end
  end
end