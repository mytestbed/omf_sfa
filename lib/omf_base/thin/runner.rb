
require 'thin'
require 'omf_base/thin/logging'

#
# Add code to Thin::Connection to verify peer certificate
#
module Thin
  class Connection
    def ssl_verify_peer(cert_s)
      true # will be verified later
    end
  end
end 

module OMF::Base::Thin
  class Runner < Thin::Runner
    include OMF::Base::Loggable
    
    @@instance = nil
    
    def self.instance
      @@instance
    end
  
    attr_reader :options
    
    def initialize(argv, opts = {})
      raise "SINGLETON" if @@instance
      
      @argv = argv
      sopts = opts.delete(:ssl) # runner has it's own idea of ssl options
      
      # Default options values
      app_name = opts[:app_name] || 'omf_web_app'
      @options = {
        :app_name             => app_name,
        :chdir                => Dir.pwd,
        :environment          => 'development',
        :address              => '0.0.0.0',
        :port                 => Thin::Server::DEFAULT_PORT,
        :timeout              => Thin::Server::DEFAULT_TIMEOUT,
        :log                  => "/tmp/#{app_name}_thin.log",
        :pid                  => "/tmp/#{app_name}.pid",
        :max_conns            => Thin::Server::DEFAULT_MAXIMUM_CONNECTIONS,
        :max_persistent_conns => Thin::Server::DEFAULT_MAXIMUM_PERSISTENT_CONNECTIONS,
        :require              => [],
        :wait                 => Thin::Controllers::Cluster::DEFAULT_WAIT_TIME,
 
        :rackup               => File.dirname(__FILE__) + '/../config.ru',
        :static_dirs          => ["#{File.dirname(__FILE__)}/../../../share/htdocs"],
        :static_dirs_pre      => ["./resources"],  # directories to prepend to 'static_dirs'
        
        :handlers             => {}  # procs to call at various times of the server's life cycle
      }.merge(opts)
      # Search path for resource files is concatination of 'pre' and 'standard' static dirs
      @options[:static_dirs] = @options[:static_dirs_pre].concat(@options[:static_dirs])
        
 
 
      print_options = false
      p = parser
      
      p.separator ""
      p.separator "Testing options:"
      p.on("--disable-https", "Run server without SSL") do sopts = nil end                
      p.on("--print-options", "Print option settings after parsing command lines args") do print_options = true end                      
  
      # Allow application to add it's own parsing options
      if ph = @options[:handlers][:pre_parse]
        ph.call(p, @options)
      end
      
      parse!

      if sopts
        @options[:ssl] = true
        @options[:ssl_key_file] ||= sopts[:key_file]
        @options[:ssl_cert_file] ||= sopts[:cert_file]
        @options[:ssl_verify] ||= sopts[:verify_peer]
      end

      # Change the name of the root logger so we can apply different logging
      # policies depending on environment. 
      #
      OMF::Base::Loggable.set_environment @options[:environment]

      if print_options
        require 'pp'
        pp @options
      end            
      
      @@instance = self
    end
    
    def life_cycle(step)
      begin
        if (p = @options[:handlers][step])
          p.arity == 0 ? p.call() : p.call(@options)
        end
      rescue => ex
        error ex
        debug "#{ex.backtrace.join("\n")}"
      end
    end    
    
    def run!
      life_cycle(:pre_run)
      super
    end
  end
end


  
