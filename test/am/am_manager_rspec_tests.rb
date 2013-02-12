require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am_manager'
require 'dm-migrations'
require 'omf_common/load_yaml'
require 'active_support/inflector'
require 'uuid'

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
  @config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

describe AMManager do

  init_logger

  init_dm

  before do
    DataMapper.auto_migrate! # reset database
  end

  let (:scheduler) do
    scheduler = Class.new do
      def self.get_nil_account
        nil
      end
      def self.create_resource(resource_descr, type_to_create, auth)
        resource_descr[:resource_type] = type_to_create
        #resource_descr[:account] = auth.account
        type = type_to_create.camelize
        resource = eval("OMF::SFA::Resource::#{type}").create(resource_descr)
        return resource
      end
      def self.release_resource(resource, authorizer)
        resource.destroy
      end
    end
    scheduler
  end

  let (:manager) { AMManager.new(scheduler) }

  
  OMF::SFA::Resource::OAccount.create({:name => 'a'})
  account = OMF::SFA::Resource::OAccount.first({:name => 'a'})

  
  describe 'leases' do

    it 'will create a lease from rspec' do
      authorizer = Minitest::Mock.new 
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:olx="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <olx:lease lease_name="l1" olx:valid_from="2013-01-08T19:00:00Z" olx:valid_until="2013-01-08T20:00:00Z"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_create_lease?, true)
      lease_elements = req.xpath('//ol:lease', 'ol' => OL_NAMESPACE)
      lease = manager.update_lease_from_rspec(lease_elements.first, authorizer)
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T20:00:00Z')
      authorizer.verify
    end

    it 'will modify lease from rspec' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.new({ :name => 'l1'})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l.uuid}" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T21:00:00Z"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_modify_lease?, true, [OMF::SFA::Resource::OLease])

      lease_elements = req.xpath('//ol:lease')
      lease = manager.update_lease_from_rspec(lease_elements.first, authorizer)
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T21:00:00Z')
      authorizer.verify
    end

    it 'will create two different leases from rspec' do
      authorizer = Minitest::Mock.new 
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease ol:lease_name="l1" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T21:00:00Z"/>
        <ol:lease ol:lease_name="l2" ol:valid_from="2013-01-08T12:00:00Z" ol:valid_until="2013-01-08T14:00:00Z"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_create_lease?, true)
      authorizer.expect(:can_create_lease?, true)

      lease_elements = req.xpath('//ol:lease')

      leases = []
      lease_elements.each do |l|
        leases << manager.update_lease_from_rspec(l, authorizer)
      end

      leases[0].name.must_equal('l1')
      leases[0].valid_from.must_equal('2013-01-08T19:00:00Z')
      leases[0].valid_until.must_equal('2013-01-08T21:00:00Z')

      leases[1].name.must_equal('l2')
      leases[1].valid_from.must_equal('2013-01-08T12:00:00Z')
      leases[1].valid_until.must_equal('2013-01-08T14:00:00Z')

      authorizer.verify
    end

    it 'will create a new lease and modify an old one from rspec' do
      authorizer = Minitest::Mock.new 
      l1 = OMF::SFA::Resource::OLease.new({ :name => 'l1'})
      l1.valid_from = '2013-01-08T19:00:00Z'
      l1.valid_until = '2013-01-08T20:00:00Z'
      l1.save
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l1.uuid}" ol:valid_from="2013-01-08T20:00:00Z" ol:valid_until="2013-01-08T21:00:00Z"/>
        <ol:lease ol:lease_name="l2" ol:valid_from="2013-01-08T12:00:00Z" ol:valid_until="2013-01-08T14:00:00Z"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_modify_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_create_lease?, true)

      lease_elements = req.xpath('//ol:lease')

      leases = []
      lease_elements.each do |l|
        leases << manager.update_lease_from_rspec(l, authorizer)
      end

      leases[0].name.must_equal('l1')
      leases[0].valid_from.must_equal('2013-01-08T20:00:00Z')
      leases[0].valid_until.must_equal('2013-01-08T21:00:00Z')

      leases[1].name.must_equal('l2')
      leases[1].valid_from.must_equal('2013-01-08T12:00:00Z')
      leases[1].valid_until.must_equal('2013-01-08T14:00:00Z')

      authorizer.verify
    end

  end # leases

  describe 'nodes and leases' do

    it 'will create a node with a lease attached to it' do
      authorizer = Minitest::Mock.new 
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease lease_name="l1" olx:valid_from="2013-01-08T19:00:00Z" olx:valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_name="l1">
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      #authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:can_create_lease?, true)
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T20:00:00Z')
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end


    it 'will create a node with an already known lease attached to it' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.new({ :name => 'l1'})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save
      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_uuid="#{l.uuid}">
        </node>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T20:00:00Z')
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end

    it 'will create a node with an already known lease attached to it (included in rspecs)' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.new({ :name => 'l1'})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l.uuid}" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T20:00:00Z"/>
        <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_uuid="#{l.uuid}"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_modify_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T20:00:00Z')
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end

    it 'will attach 2 leases(1 new and 1 old) to 2 nodes' do
      authorizer = Minitest::Mock.new 
      l1 = OMF::SFA::Resource::OLease.new({ :name => 'l1'})
      l1.valid_from = '2013-01-08T19:00:00Z'
      l1.valid_until = '2013-01-08T20:00:00Z'
      l1.save

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l1.uuid}" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T20:00:00Z"/>
        <ol:lease ol:lease_name="l2" ol:valid_from="2013-01-08T12:00:00Z" ol:valid_until="2013-01-08T14:00:00Z"/>
        <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1" ol:lease_uuid="#{l1.uuid}"/>
        <node component_id="urn:publicid:IDN+openlab+node+node2" component_name="node2" ol:lease_name="l2"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_modify_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_create_lease?, true)
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:account, account)
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, false, authorizer)

      node = r.first
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node1')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l1')
      lease.valid_from.must_equal('2013-01-08T19:00:00Z')
      lease.valid_until.must_equal('2013-01-08T20:00:00Z')
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      node = r[1]
      node.must_be_kind_of(OMF::SFA::Resource::Node)
      node.name.must_equal('node2')
      node.resource_type.must_equal('node')

      a = node.account
      a.name.must_equal('a')

      lease = node.leases.first
      lease.must_be_kind_of(OMF::SFA::Resource::OLease)
      lease.name.must_equal('l2')
      lease.valid_from.must_equal('2013-01-08T12:00:00Z')
      lease.valid_until.must_equal('2013-01-08T14:00:00Z')
      lease.components.first.must_be_kind_of(OMF::SFA::Resource::Node)

      authorizer.verify
    end
  end # nodes and leases

  describe 'clean state flag' do

    it 'will create a new node and lease without deleting the previous records' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.create({ :name => "l1", :account => account})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save

      r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})
      r.leases << l
      r.save

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease ol:lease_name="l2" ol:valid_from="2013-01-08T12:00:00Z" ol:valid_until="2013-01-08T14:00:00Z"/>
        <node component_id="urn:publicid:IDN+openlab+node+node2" component_name="node2" ol:lease_name="l2"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_create_lease?, true)
      authorizer.expect(:can_create_resource?, true, [Hash, String])
      authorizer.expect(:account, account)

      res = manager.update_resources_from_rspec(req.root, false, authorizer)

      res.length.must_equal 1
      r1 = res.first
      r1.name.must_equal('node2')
      r1.leases.first.name.must_equal('l2')

      OMF::SFA::Resource::OLease.first(:name => 'l1').wont_be_nil
      OMF::SFA::Resource::Node.first(:name => 'node1').wont_be_nil

      authorizer.verify
    end

    it 'will unlink a node from a lease and release the node' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.create({:name => 'l1', :account => account})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save

      r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})
      r.leases << l
      r.save

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="ht    tp://schema.ict-openlab.eu/sfa/rspec/1" type="request">
        <ol:lease uuid="#{l.uuid}" ol:valid_from="2013-01-08T19:00:00Z" ol:valid_until="2013-01-08T20:00:00Z"/>
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      #authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      #authorizer.expect(:can_modify_lease?, true)
      authorizer.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, true, authorizer)
      r.must_be_empty

      OMF::SFA::Resource::Node.first(:name => 'node1').must_be_nil

      l.reload
      l.components.first.must_be_nil

      OMF::SFA::Resource::OLease.first(:name => 'l1').wont_be_nil

      authorizer.verify
    end

    it 'will release a node and a lease' do
      authorizer = Minitest::Mock.new 
      l = OMF::SFA::Resource::OLease.create({:name => 'l1', :account => account})
      l.valid_from = '2013-01-08T19:00:00Z'
      l.valid_until = '2013-01-08T20:00:00Z'
      l.save

      r = OMF::SFA::Resource::Node.create({:name => 'node1', :account => account})
      r.leases << l
      r.save

      l.components.first.must_equal(r)

      rspec = %{
      <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" xmlns:ol="http://schema.ict-openlab.eu/sfa/rspec/1" type="request">
      </rspec>
      }
      req = Nokogiri.XML(rspec)

      authorizer.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      authorizer.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_release_lease?, true, [OMF::SFA::Resource::OLease])
      authorizer.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
      authorizer.expect(:account, account)
      authorizer.expect(:account, account)

      r = manager.update_resources_from_rspec(req.root, true, authorizer)

      r.must_be_empty
      OMF::SFA::Resource::Node.first(:name => 'node1').must_be_nil
      OMF::SFA::Resource::OLease.first(:name => 'l1').must_be_nil
      
      authorizer.verify
    end
  end # clean state flag

end
