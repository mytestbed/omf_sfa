
require 'omf_common/lobject'
require 'rack'

      
module OMF::SFA::AM::Rest    
  class SessionAuthenticator < OMF::Common::LObject
    
    def self.active?
      @@active
    end

    def self.authenticated?
      self[:authenticated]
    end

    def self.authenticate
      self[:authenticated] = true
      self[:valid_until] = Time.now + @@expire_after
    end
    
    def self.logout
      self[:authenticated] = false
    end

    @@store = {}
    
    def self.[](key)
      (@@store[key] || {})[:value]
    end
    
    def self.[]=(key, value)
      @@store[key] = {:value => value, :time => Time.now } # add time for GC
    end

    @@active = false
    # Expire authenticated session after being idle for that many seconds
    @@expire_after = 2592000
    
    #
    # opts -
    #   :no_session - Array of regexp to ignore
    #
    def initialize(app, opts = {})
      @app = app
      @opts = opts
      @opts[:no_session] = (@opts[:no_session] || []).map { |s| Regexp.new(s) }
      if @opts[:expire_after]
        @@expire_after = @opts[:expire_after]
      end
      @@active = true
    end
    
    
    def call(env)
      #puts env.keys.inspect
      req = ::Rack::Request.new(env)
      sid = nil
      path_info = req.path_info
      puts "REQUEST(#{self.object_id}): #{path_info}"
      unless @opts[:no_session].find {|rx| rx.match(path_info) }
        sid = req.cookies['sid'] || "s#{(rand * 10000000).to_i}_#{(rand * 10000000).to_i}"
        debug "Setting session for '#{req.path_info}' to '#{sid}'"
        Thread.current["sessionID"] = sid
        # If 'login_url' is defined, check if this session is authenticated
        login_url = @opts[:login_url] 
        if login_url && login_url != req.path_info
          if authenticated = self.class[:authenticated]
            # Check if it hasn't imed out
            if self.class[:valid_until] < Time.now
              debug "Session '#{sid}' expired"
              authenticated = false
            end    
          end
          unless authenticated
            return [301, {'Location' => login_url, "Content-Type" => ""}, ['Login first']]
          end
        end
        self.class[:valid_until] = Time.now + @@expire_after
      end
            
      status, headers, body = @app.call(env)
      if sid
        headers['Set-Cookie'] = "sid=#{sid}"  ##: name2=value2; Expires=Wed, 09-Jun-2021 ]
      end
      [status, headers, body]      
    end
  end # class
  
end # module


      
        
