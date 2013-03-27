require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am_scheduler'
require 'dm-migrations'
require 'omf_common/load_yaml'
require 'active_support/inflector'

include OMF::SFA::AM

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true 
  DataMapper.finalize

  DataMapper.auto_migrate!
end

def init_logger
  OMF::Common::Loggable.init_log 'am_scheduler', :searchPath => File.join(File.dirname(__FILE__), 'am_scheduler')
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe AMScheduler do

  init_logger

  init_dm

  before do
    DataMapper.auto_migrate! # reset database
  end

  #let (:scheduler) { scheduler = AMScheduler.new() }
  scheduler = AMScheduler.new()

  describe 'instance' do
    it 'can initialize itself' do
      scheduler.must_be_instance_of(AMScheduler)
    end
  
    it 'can return the default account' do
      a = scheduler.get_nil_account()
      a.must_be_instance_of(OMF::SFA::Resource::OAccount)
    end
  end

  describe 'resources' do

    a = scheduler.get_nil_account()
    account = OMF::SFA::Resource::OAccount.create({:name => 'a1'})

    it 'can create a node' do
      r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => a})

      authorizer = MiniTest::Mock.new
      authorizer.expect(:account, account)

      res = scheduler.create_resource({:name => 'r1', :account => account}, 'node', {}, authorizer)
      res.must_be_instance_of(OMF::SFA::Resource::Node)
      res.account.must_equal(account)
      res.provides.must_be_empty
      res.provided_by.must_equal(r)

      r1 = OMF::SFA::Resource::Node.first({:name => 'r1', :account => a})
      r1.must_equal(r)
      r1.provides.must_include(res)

      authorizer.verify
    end
  end
end
