
require 'omf-sfa/am'

# Add code to Thin::Connection to verify peer certificate
#
module Thin
  class Connection
    def ssl_verify_peer(cert_s)
      true # will be verified later
    end
  end
end 

module OMF::SFA::AM
  class Runner < Thin::Runner
    @@instance = nil
    
    def self.instance
      @@instance
    end
  
    def initialize(argv, opts = {})
      raise "SINGLETON" if @@instance
      
      @argv = argv
      sopts = opts.delete(:ssl) # runner has it's own idea of ssl options
      
      # Default options values
      @options = {
        :chdir                => Dir.pwd,
        :environment          => 'development',
        :address              => '0.0.0.0',
        :port                 => Thin::Server::DEFAULT_PORT,
        :timeout              => Thin::Server::DEFAULT_TIMEOUT,
        :log                  => 'log/thin.log',
        :pid                  => 'tmp/pids/thin.pid',
        :max_conns            => Thin::Server::DEFAULT_MAXIMUM_CONNECTIONS,
        :max_persistent_conns => Thin::Server::DEFAULT_MAXIMUM_PERSISTENT_CONNECTIONS,
        :require              => [],
        :wait                 => Thin::Controllers::Cluster::DEFAULT_WAIT_TIME
      }.merge(opts)
      
      print_options = false
      p = parser
      p.separator ""
      p.separator "Datamapper options:"
      p.on("--dm-db URL", "Datamapper database [#{@options[:dm_db]}]") do |u| @options[:dm_db] = u end    
      p.on("--dm-log FILE", "Datamapper log file [#{@options[:dm_log]}]") do |n| @options[:dm_log] = n end
      p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| @options[:dm_auto_upgrade] = true end      
      p.separator ""
      p.separator "Testing options:"
      p.on("--test-load-am", "Load an AM configuration for testing") do |n| @options[:load_test_am] = true end          
      p.on("--disable-https", "Run server without SSL") do sopts = nil end                
      p.on("--print-options", "Print option settings after parsing command lines args") do print_options = true end                      
      p.separator ""
      p.separator "Common options:"
  
      parse!

      if sopts
        @options[:ssl] = true
        @options[:ssl_key_file] ||= sopts[:key_file]
        @options[:ssl_cert_file] ||= sopts[:cert_file]
        @options[:ssl_verify] ||= sopts[:verify_peer]
      end

      if print_options
        require 'pp'
        pp @options
      end            
      
      @@instance = self
    end
    
    def init_data_mapper
  
      # Configure the data store
      #
      #DataMapper::Logger.new(@options[:dm_log] || $stdout, :debug)
      DataMapper::Logger.new($stdout, :info)
      #DataMapper::Logger.new(STDOUT, :debug)
        
      #DataMapper.setup(:default, config[:data_mapper] || {:adapter => 'yaml', :path => '/tmp/am_test2'})
      DataMapper.setup(:default, @options[:dm_db])
      
      require 'omf-sfa/resource'    
      DataMapper::Model.raise_on_save_failure = true 
      DataMapper.finalize
  
      # require  'dm-migrations'
      # DataMapper.auto_migrate!    
  
      DataMapper.auto_upgrade! if @options[:dm_auto_upgrade]
      
      load_test_am if @options[:load_test_am]
      
    end
    
    def run!
      init_data_mapper
      super
    end
  end
end


  