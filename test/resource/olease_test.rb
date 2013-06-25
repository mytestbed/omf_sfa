require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'dm-migrations'
#require 'omf_common/load_yaml'
require 'omf-sfa/resource/olease'

include OMF::SFA::Resource

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  #DataMapper.setup(:default, 'sqlite:///tmp/am_test.db')
  DataMapper::Model.raise_on_save_failure = true
  DataMapper.finalize

  DataMapper.auto_migrate!
end



describe 'OLease' do

  valid_from =Time.parse("2013-04-01 12:00:00 +0300") 
  valid_until = Time.parse("2013-04-01 13:00:00 +0300")
  
  init_dm

  before do
    DataMapper.auto_migrate! # reset database before each example
  end

  it 'will create a lease' do
    l = OMF::SFA::Resource::OLease.create(:name => 'l1')
    l.must_be_kind_of(OMF::SFA::Resource::OLease)
  end

  it 'will create a lease with oproperties' do
    l = OMF::SFA::Resource::OLease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})
    l.name.must_equal('l1')
    l.valid_from.must_equal(valid_from)
    l.valid_until.must_equal(valid_until)
  end

  it 'will find a lease by its oproperties' do
    skip # it would be good to extend Datamapper in order to enable this feature
    l1 = OMF::SFA::Resource::OLease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l2 = OMF::SFA::Resource::OLease.first({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l1.must_equal(l2)
  end

  it "will set the 'status' oproperty" do
    l1 = OMF::SFA::Resource::OLease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l1.status.must_equal("pending")
    l1.status = "accepted"

    l1.status.must_equal("accepted")
    l1.cancelled?.must_equal false
    l1.accepted?.must_equal true
  end 

  it "can have time oproperties" do
    l = OMF::SFA::Resource::OLease.create({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until})

    l.valid_from.must_be_kind_of(Time)
    l.valid_until.must_be_kind_of(Time)
  end
end
