require 'uuid'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/resource'
require 'dm-migrations'

include OMF::SFA::AM

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)

  DataMapper.setup(:default, 'sqlite::memory:')
  DataMapper::Model.raise_on_save_failure = true 
  DataMapper.finalize

  DataMapper.auto_migrate!
end

describe AMManager do

  init_dm

  before :each do
    DataMapper.auto_migrate! # reset database
    @r1 = OMF::SFA::Resource::Node.new(:name => 'r1')
    @r2 = OMF::SFA::Resource::Node.new(:name => 'r2')
    @r1.uuid = UUID.generate
    @r2.uuid = UUID.generate
  end

  let (:scheduler) { double('scheduler') }

  let (:auth) { double('authorizer') }

  let (:account) { OMF::SFA::Resource::OAccount.new(:name => 'a') }

  let (:manager) { AMManager.new(scheduler) }

  context 'leases' do

    it 'will create a lease from rspec' do

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
	<ol:lease lease_name="l1" valid_from="1338847200" valid_until="1338850800"/>
	<node component_name="r1" uuid="#{@r1.uuid}" lease_name="l1">
	  <available now="true"/>
	</node>
	<node component_name="r2" uuid="#{@r2.uuid}" lease_name="l1">
	  <available now="true"/>
	</node>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_create_lease?)

      ls = req.xpath('//ol:lease')
      r = manager.update_leases_from_rspec(ls, true, auth)
      lease = r.first
      lease.should be_a_kind_of(OMF::SFA::Resource::OLease)
      lease[:name].should eq("l1")
      lease[:valid_from] == 1338847200
      lease[:valid_until] == 1338850800
    end

    

    it 'will modify lease from rspec' do

      l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800"})
      l.should be_saved
      l.should == OMF::SFA::Resource::OLease.first({ :name => "l1" })
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
	<ol:lease lease_name="l1" valid_from="1338847200" valid_until="1338852600"/>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_view_lease?)
      auth.should_receive(:can_modify_lease?)

      ls = req.xpath('//ol:lease')
      r = manager.update_leases_from_rspec(ls, true, auth)
      lease = r.first
      lease.should be_a_kind_of(OMF::SFA::Resource::OLease)
      lease[:name].should eq("l1")
      lease[:valid_from] == 1338847200
      lease[:valid_until] == 1338852600
    end

    it 'will delete a lease from rspec' do

      l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800"})
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
	<ol:lease lease_name="l1" valid_from="0" valid_until="0"/>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_view_lease?)
      auth.should_receive(:can_cancel_lease?).with(l)

      ls = req.xpath('//ol:lease')
      r = manager.update_leases_from_rspec(ls, true, auth)
      r.should be_true

    end

    it 'will create two different leases from rspec' do

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
	<ol:lease lease_name="l1" valid_from="1338847200" valid_until="1338850800"/>
	<ol:lease lease_name="l2" valid_from="1338854400" valid_until="1338858000"/>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_create_lease?).exactly(2).times

      ls = req.xpath('//ol:lease')
      r = manager.update_leases_from_rspec(ls, true, auth)

      r[0][:name].should eq('l1')
      r[1][:name].should eq('l2')

    end
  end # context leases

  context 'combining leases with resources' do

    let(:auth) do
      auth = double('authorizer') 
      auth.stub(:account) { account }
      auth    
    end

    it 'will create a lease with a node' do

      pending "create a resource with a lease on it"
      #vr = OMF::SFA::Resource::OResource.new(:name => 'v1')
      #vr.should be_a(OMF::SFA::Resource::OResource)
      #scheduler.stub(:create_resource).and_return(vr)
      #scheduler.create_resource().should == vr

      #descr = {:name => 'r1'}
      #auth.should_receive(:can_create_resource?) #.with(descr, 'oresource')
      ##auth.should_receive(:can_view_resource?)
      #r = manager.find_or_create_resource_for_account(descr, 'oresource', auth)
      #r.should == vr

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
	<ol:lease lease_name="l1" valid_from="1338847200" valid_until="1338850800"/>
	<node component_name="r1" lease_name="l1">
	  <available now="true"/>
	</node>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_create_lease?)
      auth.should_receive(:can_create_resource?)

      r = manager.update_resources_from_rspec(req.root, true, auth)
      r.is_kind_of(OMF::SFA::Resource::OResource)
    end
  end
end

