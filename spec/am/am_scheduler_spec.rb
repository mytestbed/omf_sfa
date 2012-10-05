
require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/resource'

include OMF::SFA::AM

describe AMScheduler do

  before :all do
    init_dm
  end

  let (:manager) { double('manager') }

  let (:scheduler) { AMScheduler.new }

  context 'instance' do
    it 'can create a scheduler' do
      scheduler
    end
  end

  context 'resource' do
    
    # reset database
    before :each do
      DataMapper.auto_migrate!
    end

    let (:lease) { OMF::SFA::Resource::OLease.new(:name => 'l1') }

    let (:account) { OMF::SFA::Resource::OAccount.new(:name => 'a') }

    let (:auth) do
      auth = double('authorizer')
      auth.stub(:account) { account }
      auth
    end

    it 'can create a resource' do
      r = scheduler.create_resource({ :name => 'node1', :lease => lease, :account => account }, 'node', auth)
      r.should be_kind_of(OMF::SFA::Resource::Node)
      r.name.should be_eql('node1')
      r.account.should be_equal(account)
      r.leases.first.should be_equal(lease)
    end

    it 'can release a resource' do 
      r = scheduler.create_resource({ :name => 'node1', :lease => lease, :account => account }, 'node', auth)
      r = scheduler.release_resource(r, auth)
      r.should be_true
      OMF::SFA::Resource::Node.all.should be_empty
    end
  end
end
