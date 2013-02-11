require 'uuid'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/resource'
require 'dm-migrations'
require 'omf_common/lobject'
require 'omf_common/load_yaml'

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
  OMF::Common::Loggable.init_log 'am_manager', :searchPath => File.join(File.dirname(__FILE__), 'am_manager')       
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../etc/omf-sfa'])[:omf_sfa_am]
end


describe AMManager do

  init_dm

  init_logger

  before :each do
    DataMapper.auto_migrate! # reset database
    #  @r1 = OMF::SFA::Resource::Node.new(:name => 'r1')
    #  @r2 = OMF::SFA::Resource::Node.new(:name => 'r2')
    #  @r1.uuid = UUID.generate
    #  @r2.uuid = UUID.generate
  end

  context 'leases' do

    let (:scheduler) { double('scheduler') }

    let (:auth) { double('authorizer') }

    let (:manager) { AMManager.new(scheduler) }

    it 'will create a lease from rspec' do

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:olx="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <olx:lease lease_name="l1" olx:valid_from="1338847200" olx:valid_until="1338850800"/>
        <node component_name="r1" uuid="#{UUID.generate}" olx:lease_name="l1">
        </node>
        <node component_name="r2" uuid="#{UUID.generate}" olx:lease_name="l1">
        </node>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_create_lease?)

      lease_elements = req.xpath('//ol:lease', 'ol' => OL_NAMESPACE)
      lease = manager.update_lease_from_rspec(lease_elements.first, auth)
      lease.should be_a_kind_of(OMF::SFA::Resource::OLease)
      lease.name.should eq("l1")
      lease.valid_from == 1338847200
      lease.valid_until == 1338850800
    end



    it 'will modify lease from rspec' do

      #l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800"})
      l = OMF::SFA::Resource::OLease.new({ :name => "l1"})
      l.valid_from = "1338847200"
      l.valid_until = "1338850800"
      l.save
      l.should be_saved
      l.should == OMF::SFA::Resource::OLease.first({ :name => "l1" })
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l.uuid}" ol:valid_from="1338847200" ol:valid_until="1338852600"/>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_view_lease?)
      auth.should_receive(:can_modify_lease?)

      lease_elements = req.xpath('//ol:lease')
      lease = manager.update_lease_from_rspec(lease_elements.first, auth)
      lease.should be_a_kind_of(OMF::SFA::Resource::OLease)
      lease.name.should eq("l1")
      lease.valid_from == 1338847200
      lease.valid_until == 1338852600
    end

    it 'will create two different leases from rspec' do

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease ol:lease_name="l1" ol:valid_from="1338847200" ol:valid_until="1338850800"/>
        <ol:lease ol:lease_name="l2" ol:valid_from="1338854400" ol:valid_until="1338858000"/>
      </rspec>
      } 
      req = Nokogiri.XML(rspec)

      auth.should_receive(:can_create_lease?).exactly(2).times

      lease_elements = req.xpath('//ol:lease')

      leases = []
      lease_elements.each do |l|
        leases << manager.update_lease_from_rspec(l, auth)
      end

      leases[0].name.should eq('l1')
      leases[0].valid_from.should eq('1338847200')
      leases[0].valid_until.should eq('1338850800')

      leases[1].name.should eq('l2')
      leases[1].valid_from.should eq('1338854400')
      leases[1].valid_until.should eq('1338858000')

    end
  end # context leases

  describe AMScheduler do

    let (:scheduler) { AMScheduler.new }

    let (:manager) { AMManager.new(scheduler) }

    let (:account) { OMF::SFA::Resource::OAccount.new(:name => 'a') }

    let(:auth) do
      auth = double('authorizer') 
      auth.stub(:account) { account }
      auth    
    end

    context 'resources' do

      it 'will release a resource of type Node' do

        r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})

        OMF::SFA::Resource::Node.first(:name => 'r1').should be_eql(r)

        auth.should_receive(:can_release_resource?).with(r)
        manager.release_resource(r, auth)

        OMF::SFA::Resource::Node.first(:name => 'r1').should be_nil
      end

      it 'will release a resource that is not listed in the RSpecs' do

        r1 = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
          <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1">
          </node>
        </rspec>
        } 
        req = Nokogiri.XML(rspec)


        auth.should_receive(:can_view_resource?).exactly(2).times
        auth.should_receive(:can_release_resource?)
        auth.should_receive(:can_create_resource?)

        r = manager.update_resources_from_rspec(req.root, true, auth)

        OMF::SFA::Resource::Node.first(:name => 'r1').should be_nil

        r.length.should be_eql(1)
        r.first.name.should be_eql('node1')
      end
    end # context resources

    context 'combining leases with resources' do

      it 'will release a resource with a lease attached to it' do

        r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})

        l = OMF::SFA::Resource::OLease.create(:name => 'l1')

        r.leases << l
        r.save

        r.should be_saved

        auth.should_receive(:can_release_resource?).with(r)

        manager.release_resource(r, auth)

        OMF::SFA::Resource::Node.first(:name => 'r1').should be_nil
      end


      it 'can create a node with a lease attached to it' do

        #l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800", :account => account})
        l = OMF::SFA::Resource::OLease.new({ :name => "l1", :account => account})
        l.valid_from = '1338847200'
        l.valid_until = '1338850800'
        l.save

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
          <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_uuid="#{l.uuid}">
          </node>
        </rspec>
        } 
        req = Nokogiri.XML(rspec)

        auth.should_receive(:can_view_lease?)
        auth.should_receive(:can_create_resource?)

        r = manager.update_resources_from_rspec(req.root, false, auth)

        node = r.first
        node.should be_kind_of(OMF::SFA::Resource::Node)
        node.name.should be_eql('node1')
        node.resource_type.should be_eql('node')

        account = node.account
        account.name.should be_eql('a')

        lease = node.leases.first
        lease.should be_kind_of(OMF::SFA::Resource::OLease)
        lease.name.should be_eql('l1')
        lease.valid_from.should be_eql('1338847200')
        lease.valid_until.should be_eql('1338850800')
        lease.components.first.should be_kind_of(OMF::SFA::Resource::Node)
      end

      it 'can create a node with an already known lease attached to it' do

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
          <ol:lease ol:lease_name="l1" ol:valid_from="1338847200" ol:valid_until="1338850800"/>
          <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_name="l1">
          </node>
        </rspec>
        } 
        req = Nokogiri.XML(rspec)

      end

    end # combining leases with resources

    context 'clean state' do

      it 'will create a new node and lease without deleting the previous' do

        #l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800", :account => account})
        l = OMF::SFA::Resource::OLease.create({ :name => "l1", :account => account})
        l.valid_from = '1338847200'
        l.valid_until = '1338850800'
        l.save

        r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})
        r.leases << l
        r.save

        r.should be_saved

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
          <ol:lease ol:lease_name="l2" ol:valid_from="1338847200" ol:valid_until="1338850800"/>
          <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_name="l2">
          </node>
        </rspec>
        } 
        req = Nokogiri.XML(rspec)

        auth.should_receive(:can_create_lease?)
        auth.should_receive(:can_create_resource?)

        res = manager.update_resources_from_rspec(req.root, false, auth)

        res.length == 1
        res = res.first
        res.name.should be_eql('node1')
        res.leases.first.name.should be_eql('l2')

        OMF::SFA::Resource::OLease.first(:name => 'l1').should_not be_nil
        OMF::SFA::Resource::Node.first(:name => 'r1').should_not be_nil
      end

      it 'will unlink a node from a lease and release the node' do

        #l = OMF::SFA::Resource::OLease.create({:name => "l1", :valid_from => "1338847200", :valid_until => "1338850800", :account => account})
        l = OMF::SFA::Resource::OLease.create({:name => "l1", :account => account})
        l.valid_from = '1338847200'
        l.valid_until = '1338850800'
        l.save

        r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})
        r.leases << l
        r.save

        r.should be_saved

        l.components.first.should be_eql(r)

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
          <ol:lease uuid="#{l.uuid}" ol:valid_from="1338847200" ol:valid_until="1338850800"/>
        </rspec>
        } 
        req = Nokogiri.XML(rspec)

        auth.should_receive(:can_view_resource?)
        auth.should_receive(:can_view_lease?).exactly(2).times
        auth.should_receive(:can_modify_lease?)
        auth.should_receive(:can_release_resource?).with(r)

        r = manager.update_resources_from_rspec(req.root, true,  auth)

        r.should == []
        OMF::SFA::Resource::Node.first(:name => 'r1').should be_nil

        l.reload
        l.components.first.should be_nil

        OMF::SFA::Resource::OLease.first(:name => 'l1').should_not be_nil
      end

      it 'will release a node and a lease' do

        #l = OMF::SFA::Resource::OLease.create({ :name => "l1", :valid_from => "1338847200", :valid_until => "1338850800", :account => account})
        l = OMF::SFA::Resource::OLease.create({ :name => "l1", :account => account})
        l.valid_from = '1338847200'
        l.valid_until = '1338850800'
        l.save

        r = OMF::SFA::Resource::Node.create({:name => 'r1', :account => account})
        r.leases << l
        r.save

        r.should be_saved

        l.components.first.should be_eql(r)

        rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        </rspec>
        } 
        req = Nokogiri.XML(rspec)

        auth.should_receive(:can_view_resource?)
        auth.should_receive(:can_view_lease?).with(l)
        auth.should_receive(:can_release_lease?).with(l)
        auth.should_receive(:can_release_resource?).with(r)
        #auth.should_receive(:can_release_resource?).with(l)

        r = manager.update_resources_from_rspec(req.root, true,  auth)

        r.should == []
        OMF::SFA::Resource::Node.first(:name => 'r1').should be_nil
        OMF::SFA::Resource::OLease.first(:name => 'l1').should be_nil

      end

    end # context clean state
  end
end

