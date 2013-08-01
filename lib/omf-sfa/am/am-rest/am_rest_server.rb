require 'rubygems'
require 'json'

require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'data_mapper'
require 'omf_base/lobject'
require 'omf_base/load_yaml'

require 'omf-sfa/am/am_runner'
#require 'omf-sfa/am/am_manager'
#require 'omf-sfa/am/am_scheduler'

require 'omf_base/lobject'

module OMF::SFA::AM::Rest

  class Server
    # Don't use LObject as we haveb't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Common::Loggable
    extend OMF::Common::Loggable

    def init_logger
      OMF::Common::Loggable.init_log 'server', :searchPath => File.join(File.dirname(__FILE__), 'server')

      #@config = OMF::Common::YAML.load('config', :path => [File.dirname(__FILE__) + '/../../../etc/gimi-exp-service'])[:gimi_exp_service]
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
    end


    def load_test_state(options)
      require 'omf-sfa/am/am-rest/rest_handler'
      OMF::SFA::AM::Rest::RestHandler.set_service_name("OMF Test AM")

      require  'dm-migrations'
      DataMapper.auto_migrate!

      am = nil

      require 'omf-sfa/resource/oaccount'
      #account = am.find_or_create_account(:name => 'foo')
      account = OMF::SFA::Resource::OAccount.create(:name => 'system')
      slice1 = OMF::SFA::Resource::OAccount.create(
                :name => 'slice1',
                :uuid => UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, 'slice1')
      )

      require 'omf-sfa/resource/node'
      nodes = []
      3.times do |i|
        name = "n#{i}"
        uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, name)
        nodes << (n = OMF::SFA::Resource::Node.create(:name => name, :uuid => uuid, :account => slice1))
        am.manage_resource(n) if am
        n.save
        #puts ">>>> #{n.inspect}"
      end
    end

    def run(opts)
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda {
        },
        :pre_parse => lambda do |p, options|
          p.on("--test-load-am", "Load an initial state for testing") do |n| options[:load_test_state] = true end
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:dm_db]}]") do |u| options[:dm_db] = u end
          p.on("--dm-log FILE", "Datamapper log file [#{options[:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          p.separator ""
        end,
        :pre_run => lambda do |opts|
          init_logger()
          init_data_mapper(opts)
          load_test_state(opts) if opts[:load_test_state]
        end
      }


      #Thin::Logging.debug = true
      require 'omf_base/thin/runner'
      OMF::Common::Thin::Runner.new(ARGV, opts).run!
    end
  end # class
end # module

if __FILE__ == $0
  opts = {
    :app_name => 'am_rest_server',
    :port => 8004,
    # :am => {
      # :manager => lambda { OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new) }
    # },
    :ssl => {
      :cert_file => File.expand_path("~/.gcf/am-cert.pem"),
      :key_file => File.expand_path("~/.gcf/am-key.pem"),
      :verify_peer => true
      #:verify_peer => false
    },
    #:log => '/tmp/am_server.log',
    :dm_db => 'sqlite:///tmp/am_test.db',
    :dm_log => '/tmp/am_test-dm.log',
    :rackup => File.dirname(__FILE__) + '/config.ru',

  }
  OMF::SFA::AM::Rest::Server.new.run(opts)

end

######################

# require 'rubygems'
# require 'rack'
# require 'rack/showexceptions'
# require 'thin'
# require 'data_mapper'
# require 'omf_base/lobject'
# require 'omf_base/load_yaml'
# require 'uuidtools'
# require 'omf-sfa/am/am_manager'
#
# OMF::Common::Loggable.init_log 'am_server'
# config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../../etc/omf-sfa'])[:omf_sfa_am]
#
# class MyRunner < Thin::Runner
  # @@instance = nil
#
  # def self.instance
    # @@instance
  # end
#
  # def initialize(argv, opts = {})
    # raise "SINGLETON" if @@instance
#
    # @argv = argv
#
    # # Default options values
    # @options = {
      # :chdir                => Dir.pwd,
      # :environment          => 'development',
      # :address              => '0.0.0.0',
      # :port                 => Thin::Server::DEFAULT_PORT,
      # :timeout              => Thin::Server::DEFAULT_TIMEOUT,
      # :log                  => 'log/thin.log',
      # :pid                  => 'tmp/pids/thin.pid',
      # :max_conns            => Thin::Server::DEFAULT_MAXIMUM_CONNECTIONS,
      # :max_persistent_conns => Thin::Server::DEFAULT_MAXIMUM_PERSISTENT_CONNECTIONS,
      # :require              => [],
      # :wait                 => Thin::Controllers::Cluster::DEFAULT_WAIT_TIME
    # }.merge(opts)
#
    # p = parser
    # p.separator ""
    # p.separator "Datamapper options:"
    # p.on("--dm-db URL", "Datamapper database [#{@options[:dm_db]}]") do |u| @options[:dm_db] = u end
    # p.on("--dm-log FILE", "Datamapper log file [#{@options[:dm_log]}]") do |n| @options[:dm_log] = n end
    # p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| @options[:dm_auto_upgrade] = true end
    # p.separator ""
    # p.separator "Testing options:"
    # p.on("--test-load-am", "Load an AM configuration for testing") do |n| @options[:load_test_am] = true end
    # p.separator ""
    # p.separator "Common options:"
#
    # parse!
    # @@instance = self
  # end
#
  # def init_data_mapper
#
    # # Configure the data store
    # #
    # DataMapper::Logger.new(@options[:dm_log] || $stdout, :debug)
#
    # #DataMapper.setup(:default, config[:data_mapper] || {:adapter => 'yaml', :path => '/tmp/am_test2'})
    # dm = DataMapper.setup(:default, @options[:dm_db])
    # DataMapper::Model.raise_on_save_failure = true
#
    # require 'omf-sfa/resource'
    # DataMapper.finalize
#
    # DataMapper.auto_upgrade! if @options[:dm_auto_upgrade]
#
    # load_test_am if @options[:load_test_am]
  # end
# end
#
# def load_test_am
  # require  'dm-migrations'
  # DataMapper.auto_migrate!
#
  # am = @options[:am_mgr]
#
  # require 'omf-sfa/resource/oaccount'
  # account = am.find_or_create_account(:name => 'foo')
#
  # require 'omf-sfa/resource/node'
  # nodes = []
  # 3.times do |i|
    # name = "n#{i}"
    # uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, name)
    # nodes << (n = OMF::SFA::Resource::Node.create(:name => name, :uuid => uuid))
    # am.manage_resource(n) if am
  # end
# #  am.find_resource 'n1', :requester_account => account
#
# end
#
# # Configure the web server
# #
# opts = {
  # :port => 8001,
  # :am => {
    # #:manager => OMF::SFA::AM::AMManager.new
  # },
  # :sslX => {
    # :cert_chain_file => File.expand_path("~/.gcf/am-cert.pem"),
    # :private_key_file => File.expand_path("~/.gcf/am-key.pem"),
    # #:verify_peer => true
    # :verify_peer => true
  # },
  # :log => '/tmp/am_server.log',
  # :dm_db => 'sqlite::memory:', # 'sqlite:///tmp/am_test.db',
  # :dm_log => '/tmp/am_server-dm.log',
  # :rackup => File.dirname(__FILE__) + '/config.ru'
#
# }
#
#
# Thin::Logging.debug = true
# MyRunner.new(ARGV, opts).run!
