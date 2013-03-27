require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
#require 'data_mapper'
require 'dm-migrations'
require 'omf_common/lobject'
require 'omf_common/load_yaml'

require 'omf-sfa/am/am_runner'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/am/am_liaison'

#require 'omf_common/lobject'

module OMF::SFA::AM

  class AMServer 
    # Don't use LObject as we haven't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Common::Loggable
    extend OMF::Common::Loggable
    
    def init_logger
      OMF::Common::Loggable.init_log 'am_server', :searchPath => File.join(File.dirname(__FILE__), 'am_server')
      
      @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]
    end
    
    def load_trusted_cert_roots
      # Add additional cert roots. TODO:Should really come from the config file
      
      [ '~/.gcf/trusted_roots/CATedCACerts.pem', 
        '~/.sfi/topdomain.subdomain.authority.cred', 
        '/etc/sfa/trusted_roots/topdomain.gid'
      ].each do |fn|
        fne = File.expand_path(fn)
        if File.readable?(fne)
          trusted_cert = OpenSSL::X509::Certificate.new(File.read(fne))
          OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)
        else
          warn "Can't find trusted root cert '#{fne}'"
        end
      end
    end
    
    def init_data_mapper(options)
      #@logger = OMF::Common::Loggable::_logger('am_server')
      #OMF::Common::Loggable.debug "options: #{options}"
      debug "options: #{options}"
    
      # Configure the data store
      #
      DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
      #DataMapper::Logger.new($stdout, :info)
        
      #DataMapper.setup(:default, config[:data_mapper] || {:adapter => 'yaml', :path => '/tmp/am_test2'})
      DataMapper.setup(:default, options[:dm_db])
      
      require 'omf-sfa/resource'    
      DataMapper::Model.raise_on_save_failure = true 
      DataMapper.finalize
    
      # require  'dm-migrations'
      # DataMapper.auto_migrate!    
    
      DataMapper.auto_upgrade! if options[:dm_auto_upgrade]
      load_test_am(options) if options[:load_test_am]
    end
    
    
    def load_test_am(options)
      require  'dm-migrations'
      DataMapper.auto_migrate!
      
      am = options[:am][:manager]
      if am.is_a? Proc
        am = am.call
        options[:am][:manager] = am
      end
    
      require 'omf-sfa/resource/oaccount'
      #account = am.find_or_create_account(:name => 'foo')
      account = OMF::SFA::Resource::OAccount.new(:name => 'foo')
      
      require 'omf-sfa/resource/node'
      nodes = []
      3.times do |i|
        name = "node#{i}"
        uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, name)
        nodes << (n = OMF::SFA::Resource::Node.create(:name => name, :uuid => uuid))
        am.manage_resource(n)
      end
      #  am.find_resource 'n1', :requester_account => account
    end
    
    def run(opts)
      # alice = OpenSSL::X509::Certificate.new(File.read('/Users/max/.gcf/alice-cert.pem'))
      # puts "ALICE::: #{OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(alice)}"
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda { 
        },
        :pre_parse => lambda do |p, options|
          p.on("--test-load-am", "Load an AM configuration for testing") do |n| options[:load_test_am] = true end          
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:dm_db]}]") do |u| options[:dm_db] = u end    
          p.on("--dm-log FILE", "Datamapper log file [#{options[:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end      
          p.separator ""
        end,
        :pre_run => lambda do |opts|
          init_logger()
          load_trusted_cert_roots()
          init_data_mapper(opts)    
        end
      }

      #Thin::Logging.debug = true
      require 'omf_common/thin/runner'
      OMF::Common::Thin::Runner.new(ARGV, opts).run!
    end

  end # class
end # module

# Configure the web server
#
opts = {
  :app_name => 'am_server',
  :port => 8001,
  :am => {
    :manager => lambda { OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new) },
    :liaison => OMF::SFA::AM::AMLiaison.new
  },
  :ssl => {
    :cert_file => File.expand_path("~/.gcf/am-cert.pem"), 
    :key_file => File.expand_path("~/.gcf/am-key.pem"), 
    :verify_peer => true
    #:verify_peer => false
  },
  #:log => '/tmp/am_server.log',
  :dm_db => 'sqlite:///tmp/am_test.db',
  :dm_log => '/tmp/am_server-dm.log',
  :rackup => File.dirname(__FILE__) + '/config.ru',
  
}
OMF::SFA::AM::AMServer.new.run(opts)



