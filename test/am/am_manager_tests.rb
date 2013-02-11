require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'omf-sfa/am/am_manager'
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
        resource_descr[:account] = auth.account
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

  describe 'instance' do
    it 'can create an AM Manager' do
      manager
    end
  
    it 'can create an AM Manager' do
      r = OMF::SFA::Resource::OResource.create(:name => 'r')
      manager.manage_resource(r)
    end
  end

  describe 'account' do
    let(:auth) { MiniTest::Mock.new }

    before do
      DataMapper.auto_migrate! # reset database
    end
        
    it 'can create account' do
      auth.expect(:can_create_account?, true)
      account = manager.find_or_create_account({:name => 'a'}, auth)
      account.must_be_instance_of(OMF::SFA::Resource::OAccount)
      auth.verify
    end

    it 'can find created account' do
      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a'}, auth)
             
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      a2 = manager.find_or_create_account({:name => 'a'}, auth)
      a1.must_equal a2
      
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      a3 = manager.find_account({:name => 'a'}, auth)
      a1.must_equal a3
      auth.verify
    end
    
    it 'throws exception when looking for non-exisiting account' do
      lambda do 
        manager.find_account({:name => 'a'}, auth)
      end.must_raise(UnavailableResourceException)
    end
    
    it 'can request all accounts visible to a user' do
      manager.find_all_accounts(auth).must_be_empty 

      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      manager.find_all_accounts(auth).must_equal [a1]
      
      auth.expect(:can_create_account?, true)
      a2 = manager.find_or_create_account({:name => 'a2'}, auth)
       
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])
      
      manager.find_all_accounts(auth).must_equal [a1, a2]
      auth.verify

      def auth.can_view_account?(account)
        raise InsufficientPrivilegesException
      end  
      manager.find_all_accounts(auth).must_be_empty
      
    end
    
    it 'can request accounts which are active' do
      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      a2 = manager.find_active_account({:name => 'a1'}, auth)
      a2.wont_be_nil

      # Expire account
      a2.valid_until = Time.now - 100
      a2.save
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      lambda do
        manager.find_active_account({:name => 'a1'}, auth)
      end.must_raise(UnavailableResourceException)
      auth.verify
    end
    
    it 'can renew accounts' do
      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)

      time = Time.now + 100
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      auth.expect(:can_renew_account?, true, [a1, time])            
      a2 = manager.renew_account_until({:name => 'a1'}, time, auth)
      auth.verify

      a2.valid_until.must_equal time
    end
    
    it 'can close account' do
      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      a1.active?.must_equal true
      a1.closed?.must_equal false
      
      auth.expect(:can_view_account?, true, [OMF::SFA::Resource::OAccount])      
      auth.expect(:can_close_account?, true, [a1])   
      a2 = manager.close_account({:name => 'a1'}, auth)
      a2.reload
      a2.active?.must_equal false
      a2.closed?.must_equal true
      auth.verify
    end
  end #account

  describe 'users' do

    before do
      DataMapper.auto_migrate! # reset database
    end

    it 'can create a user' do
      u = manager.find_or_create_user({:urn => 'urn:publicid:IDN+topdomain:subdomain+user+pi'})
      u.must_be_instance_of(OMF::SFA::Resource::User)
    end

    it 'can find an already created user' do
      user_descr = {:urn => 'urn:publicid:IDN+topdomain:subdomain+user+pi'}
      u1 = OMF::SFA::Resource::User.create(user_descr)
      u2 = manager.find_or_create_user(user_descr)
      u1.must_equal u2

      u2 = manager.find_user(user_descr)
      u1.must_equal u2
    end

    it 'throws an exception when looking for a non existing user' do
      lambda do
        manager.find_user({:urn => 'urn:publicid:IDN+topdomain:subdomain+user+pi'})
      end.must_raise(UnavailableResourceException)
    end

  end #users

  describe 'lease' do

    let(:auth) { MiniTest::Mock.new }

    lease_oproperties = {:valid_from => Time.now, :valid_until => Time.now + 100}

    before do
      DataMapper.auto_migrate! # reset database
    end
        
    it 'can create lease' do
      auth.expect(:can_create_lease?, true)
      lease = manager.find_or_create_lease({:name => 'l1'}, lease_oproperties, auth) 
      lease.must_be_instance_of(OMF::SFA::Resource::OLease)
      auth.verify
    end

    it 'can find created lease' do
      auth.expect(:can_create_lease?, true)
      a1 = manager.find_or_create_lease({:name => 'l1'}, lease_oproperties, auth)
             
      auth.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])      
      a2 = manager.find_or_create_lease({:name => 'l1'}, lease_oproperties, auth)
      a1.must_equal a2
      
      auth.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])      
      a3 = manager.find_lease({:name => 'l1'}, auth)
      a1.must_equal a3
      auth.verify
    end

    it 'throws exception when looking for non-exisiting lease' do
      lambda do 
        manager.find_lease({:name => 'l1'}, auth)
      end.must_raise(UnavailableResourceException)
    end

    it "can request all user's leases" do
      OMF::SFA::Resource::OLease.create({:name => "another_user's_lease"})

      auth.expect(:can_create_account?, true)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)

      manager.find_all_leases_for_account(a1, auth).must_be_empty   

      auth.expect(:can_create_lease?, true)
      l1 = manager.find_or_create_lease({:name => 'l1', :account => a1}, lease_oproperties, auth)
      
      auth.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])      
      manager.find_all_leases_for_account(a1, auth).must_equal [l1]
      
      auth.expect(:can_create_lease?, true)
      l2 = manager.find_or_create_lease({:name => 'l2', :account => a1}, lease_oproperties, auth)
       
      auth.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      auth.expect(:can_view_lease?, true, [OMF::SFA::Resource::OLease])
      manager.find_all_leases_for_account(a1, auth).must_equal [l1, l2]

      def auth.can_view_lease?(lease)
        raise InsufficientPrivilegesException
      end   
      manager.find_all_leases_for_account(a1, auth).must_be_empty
      auth.verify
    end

    it 'can modify leases' do
      auth.expect(:can_create_lease?, true)
      l1 = manager.find_or_create_lease({:name => 'l1'}, lease_oproperties, auth)
      auth.verify

      valid_from = 1338847200
      valid_until = 1338850800
      auth.expect(:can_modify_lease?, true, [l1])            
      l2 = manager.modify_lease({:valid_from => valid_from, :valid_until => valid_until}, l1, auth)
      auth.verify
      l2.must_equal l1.reload
      l2.valid_from.must_equal valid_from
      l2.valid_until.must_equal valid_until
    end
    
    it 'can release a lease' do
      auth.expect(:can_create_lease?, true)
      l1 = manager.find_or_create_lease({:name => 'l1'}, lease_oproperties, auth)
      auth.verify
      
      auth.expect(:can_release_lease?, true, [l1])   
      manager.release_lease(l1, auth)
      auth.verify
      l1.reload
      l1.cancelled?.must_equal true
    end

  end #lease

  describe 'resource' do

    account = OMF::SFA::Resource::OAccount.create(:name => 'a')

    auth = Minitest::Mock.new
    
    before do
      DataMapper.auto_migrate! # reset database
    end
    
    it 'finds single resource belonging to anyone through its name (Hash)' do
      r1 = OMF::SFA::Resource::OResource.create(:name => 'r1')
      manager.manage_resources([r1])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_resource({:name => 'r1'}, auth)
      auth.verify
      r.must_be_instance_of(OMF::SFA::Resource::OResource)
    end

    it 'finds single resource belonging to anyone through its name (String)' do
      r1 = OMF::SFA::Resource::OResource.create(:name =>'r1')
      manager.manage_resources([r1])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_resource('r1', auth)
      auth.verify
      r.must_be_instance_of(OMF::SFA::Resource::OResource)
    end

    it 'finds a resource through its instance' do
      r1 = OMF::SFA::Resource::Node.create(:name => 'r1')
      manager.manage_resources([r1])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      r = manager.find_resource(r1, auth)
      auth.verify
      r.must_be_instance_of(OMF::SFA::Resource::Node)
    end

    it 'finds a resource through its uuid' do
      r1 = OMF::SFA::Resource::OResource.create(:uuid => '759ae077-2fda-4d02-8921-ab0235a09920')
      manager.manage_resources([r1])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_resource('759ae077-2fda-4d02-8921-ab0235a09920', auth)
      auth.verify
      r.must_be_instance_of(OMF::SFA::Resource::OResource)
    end

    it 'throws an exception for unknown resource description' do
      lambda do
        manager.find_resource(nil, auth)
      end.must_raise(FormatException)
    end

    it 'throws an exception when looking for a non existing resource' do
      lambda do
        manager.find_resource('r1', auth)
      end.must_raise(UnknownResourceException)
    end

    it 'throws an exception when is not privileged to view the resource' do
      authorizerr = Minitest::Mock.new
      r1 = OMF::SFA::Resource::OResource.create(:name =>'r1')
      manager.manage_resources([r1])

      def authorizerr.can_view_resource?(*args)
        raise InsufficientPrivilegesException.new
      end
      
      lambda do
        manager.find_resource('r1', authorizerr)
      end.must_raise(InsufficientPrivilegesException)
    end

    it 'finds single resource belonging to an account' do
      r1 = OMF::SFA::Resource::OResource.create(:name => 'r1')
      manager.manage_resources([r1])
      
      auth.expect(:account, account)
      lambda do
        manager.find_resource_for_account({:name => 'r1'}, auth)
      end.must_raise(UnknownResourceException)
      auth.verify
 
      # now, assign it to this account
      r1.account = account
      r1.save
      auth.expect(:account, account)
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_resource_for_account({:name => 'r1'}, auth)
      auth.verify
      r.must_equal r1
    end

    it 'will find all the resources of an account' do
      r1 = OMF::SFA::Resource::OResource.create({:name => 'r1', :account => account})
      r2 = OMF::SFA::Resource::OResource.create({:name => 'r2', :account => account})
      r3 = OMF::SFA::Resource::OResource.create({:name => 'r3'})

      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_all_resources_for_account(account, auth)
      r.must_equal [r1, r2]
      auth.verify
    end

    it 'will find all the components of an account' do
      r1 = OMF::SFA::Resource::OComponent.create({:name => 'r1', :account => account})
      r2 = OMF::SFA::Resource::Node.create({:name => 'r2', :account => account})
      r3 = OMF::SFA::Resource::OResource.create({:name => 'r3', :account => account})

      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_all_components_for_account(account, auth)
      r.must_equal [r1, r2]
      auth.verify
    end

    it 'will find all the components' do
      r1 = OMF::SFA::Resource::OComponent.create({:name => 'r1', :account => account})
      r2 = OMF::SFA::Resource::Node.create({:name => 'r2', :account => account})
      r3 = OMF::SFA::Resource::OResource.create({:name => 'r3', :account => account})
      r4 = OMF::SFA::Resource::OComponent.create({:name => 'r4'})

      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_all_components_for_account(nil, auth)
      r.must_equal [r1, r2, r4]
      auth.verify
    end

    it 'will create a resource' do
      resource_descr = {:name => 'r1'}
      type_to_create = 'node'
      auth.expect(:account, account)
      auth.expect(:can_create_resource?, true, [Hash, String])
      r = manager.find_or_create_resource(resource_descr, type_to_create, auth)
      auth.verify
      r.must_equal OMF::SFA::Resource::Node.first(:name => 'r1')
    end

    it 'will find an already created resource' do
      resource_descr = {:name => 'r1'}
      r1 = OMF::SFA::Resource::OResource.create(resource_descr)
      type_to_create = 'node'
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OResource])
      r = manager.find_or_create_resource(resource_descr, type_to_create, auth)
      auth.verify
      r.must_equal r1
    end

    it 'will create a resource if not already available for the account' do
      auth.expect(:account, account)
      auth.expect(:account, account)
      auth.expect(:can_create_resource?, true, [Hash, String])
      descr = {:name => 'v1'}
      r = manager.find_or_create_resource_for_account(descr, 'o_resource', auth)
      auth.verify
      vr = OMF::SFA::Resource::OResource.first({:name => 'v1', :account => account})
      r.must_equal vr
    end

    it 'will create resource from rspec' do
      rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" type="request">
          <node component_id="urn:publicid:IDN+openlab+node+node1" component_name="node1">
          </node>
        </rspec>
      } 
      req = Nokogiri.XML(rspec)
      
      auth.expect(:can_create_resource?, true, [Hash, String])
      auth.expect(:account, account)
      auth.expect(:account, account)    
      r = manager.update_resources_from_rspec(req.root, false, auth)
      auth.verify
      r.first.must_equal OMF::SFA::Resource::Node.first(:name => 'node1')
    end

    it 'will release a resource' do
      r1 = OMF::SFA::Resource::OResource.create(:name => 'r1')
      manager.manage_resources([r1])
      auth.expect(:can_release_resource?, true, [r1])

      manager.release_resource(r1, auth)
      auth.verify
      OMF::SFA::Resource::OResource.first(:name => 'r1').must_be_nil
    end

    it 'will release all components of an account' do
      OMF::SFA::Resource::OResource.create({:name => 'r1', :account => account})
      OMF::SFA::Resource::Node.create({:name => 'n1', :account => account})
      OMF::SFA::Resource::Node.create({:name => 'n2'})
      OMF::SFA::Resource::OComponent.create({:name => 'c1', :account => account})

      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::Node])
      auth.expect(:can_view_resource?, true, [OMF::SFA::Resource::OComponent])
      auth.expect(:can_release_resource?, true, [OMF::SFA::Resource::Node])
      auth.expect(:can_release_resource?, true, [OMF::SFA::Resource::OComponent])
      manager.release_all_components_for_account(account, auth)
      OMF::SFA::Resource::OResource.first({:account => account}).wont_be_nil
      OMF::SFA::Resource::Node.first({:account => account}).must_be_nil
      OMF::SFA::Resource::OComponent.first({:account => account}).must_be_nil
      OMF::SFA::Resource::Node.first({:name => 'n2'}).wont_be_nil
      auth.verify
    end

  end #resource

end
