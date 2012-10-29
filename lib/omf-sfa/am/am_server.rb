require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'data_mapper'
require 'omf_common/lobject'
require 'omf_common/load_yaml'

require 'omf-sfa/am/am_runner'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'


OMF::Common::Loggable.init_log 'am_server'
config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]

# Add additional cert roots. TODO:Should really come from the config file
trusted_cert_file = File.expand_path('~/.gcf/trusted_roots/CATedCACerts.pem')
trusted_cert = OpenSSL::X509::Certificate.new(File.read(trusted_cert_file))
OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)

trusted_cert_file = File.expand_path('~/.sfi/topdomain.subdomain.authority.cred')
trusted_cert = OpenSSL::X509::Certificate.new(File.read(trusted_cert_file))
OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)

trusted_cert_file = File.expand_path('/etc/sfa/trusted_roots/topdomain.gid')
trusted_cert = OpenSSL::X509::Certificate.new(File.read(trusted_cert_file))
OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)

# Configure the web server
#
opts = {
  :port => 8001,
  :am => {
    :manager => lambda { OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new) }
  },
  :ssl => {
    :cert_file => File.expand_path("~/.gcf/am-cert.pem"), 
    :key_file => File.expand_path("~/.gcf/am-key.pem"), 
    :verify_peer => true
    #:verify_peer => false
  },
  :log => '/tmp/am_server.log',
  :dm_db => 'sqlite:///tmp/am_test.db',
  :dm_log => '/tmp/am_server-dm.log',
  :rackup => File.dirname(__FILE__) + '/config.ru'
}


def load_test_am
  require  'dm-migrations'
  DataMapper.auto_migrate!
  
  am = @options[:am][:manager]
  if am.is_a? Proc
    am = am.call
  end

  require 'omf-sfa/resource/oaccount'
  #account = am.find_or_create_account(:name => 'foo')
  account = OMF::SFA::Resource::OAccount.new(:name => 'foo')
  
  require 'omf-sfa/resource/node'
  nodes = []
  3.times do |i|
    name = "n#{i}"
    uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, name)
    nodes << (n = OMF::SFA::Resource::Node.create(:name => name, :uuid => uuid))
    am.manage_resource(n)
  end
#  am.find_resource 'n1', :requester_account => account
  
end



# alice = OpenSSL::X509::Certificate.new(File.read('/Users/max/.gcf/alice-cert.pem'))
# puts "ALICE::: #{OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(alice)}"



Thin::Logging.debug = true
OMF::SFA::AM::Runner.new(ARGV, opts).run!
