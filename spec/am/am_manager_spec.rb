
require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/am/am_manager'
require 'omf-sfa/resource'
require "rspec/expectations"

include OMF::SFA::AM

describe AMManager do
  before :all do
    init_dm
  end
  
  let (:scheduler) do
    scheduler = double('scheduler')
    scheduler.stub(:get_nil_account).and_return(nil)
    scheduler 
  end
  let (:manager) { AMManager.new(scheduler) }
  
  context 'instance' do
    it 'can create an AM Manager' do
      manager
    end
  
    it 'can create an AM Manager' do
      r = OMF::SFA::Resource::OResource.new(:name => 'r')
      manager.manage_resource(r)
    end
  end
  
  context 'account' do
    #let(:auth) { AuthorizerMock.new }
    let(:auth) { double('authorizer') }

    before :each do
      DataMapper.auto_migrate! # reset database
    end
        
    it 'can create account' do
      auth.should_receive(:can_create_account?)#.with("02134")
      account = manager.find_or_create_account({:name => 'a'}, auth) 
      account.should be_a(OMF::SFA::Resource::OAccount)
    end

    it 'can find created account' do
      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a'}, auth)
             
      auth.should_receive(:can_view_account?).with(kind_of(OMF::SFA::Resource::OAccount))      
      a2 = manager.find_or_create_account({:name => 'a'}, auth)
      a2.reload      
      a1.should == a2
      
      auth.should_receive(:can_view_account?).with(kind_of(OMF::SFA::Resource::OAccount))      
      a3 = manager.find_account({:name => 'a'}, auth)
      a3.reload
      a1.should == a3
    end
    
    it 'throws exception when looking for non-exisiting account' do
      lambda do 
        manager.find_account({:name => 'a'}, auth)
      end.should raise_error(UnavailableResourceException)
    end
    
    it 'can request all accounts visible to a user' do
      manager.find_all_accounts(auth).should == []   

      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      
      auth.should_receive(:can_view_account?)      
      manager.find_all_accounts(auth).should == [a1]
      
      auth.should_receive(:can_create_account?)
      a2 = manager.find_or_create_account({:name => 'a2'}, auth)
       
      auth.should_receive(:can_view_account?).exactly(2).times
      manager.find_all_accounts(auth).should == [a1, a2]

      auth.should_receive(:can_view_account?).exactly(2).times.and_raise(InsufficientPrivilegesException)    
      manager.find_all_accounts(auth).should == []
    end
    
    it 'can request accounts which are active' do
      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      
      auth.should_receive(:can_view_account?)      
      a2 = manager.find_active_account({:name => 'a1'}, auth)
      a2.should_not be_nil

      # Expire account
      a2.valid_until = Time.now - 100
      a2.save
      auth.should_receive(:can_view_account?)      
      lambda do
        manager.find_active_account({:name => 'a1'}, auth)
      end.should raise_error(UnavailableResourceException) 
    end
    
    it 'can renew accounts' do
      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)

      time = Time.now + 100
      auth.should_receive(:can_view_account?)      
      auth.should_receive(:can_renew_account?).with(a1, time)            
      a2 = manager.renew_account_until({:name => 'a1'}, time, auth)
      a2.should == a1
      a2.valid_until.should == time
    end
    
    it 'can close account' do
      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)
      a1.active?.should be_true
      a1.closed?.should be_false
      
      auth.should_receive(:can_view_account?)      
      auth.should_receive(:can_close_account?).with(a1)   
      a2 = manager.close_account({:name => 'a1'}, auth)
      a2.reload
      a2.active?.should be_false
      a2.closed?.should be_true
    end
  end # context - account

  context 'lease' do

    let(:auth) { double('authorizer') }

    before :each do
      DataMapper.auto_migrate! # reset database
    end
        
    it 'can create lease' do
      auth.should_receive(:can_create_lease?)
      lease = manager.find_or_create_lease({:name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 100}, auth) 
      lease.should be_a(OMF::SFA::Resource::OLease)
    end

    it 'can find created lease' do
      auth.should_receive(:can_create_lease?)
      a1 = manager.find_or_create_lease({:name => 'l1'}, auth)
             
      auth.should_receive(:can_view_lease?).with(kind_of(OMF::SFA::Resource::OLease))      
      a2 = manager.find_or_create_lease({:name => 'l1'}, auth)
      a2.reload      
      a1.should == a2
      
      auth.should_receive(:can_view_lease?).with(kind_of(OMF::SFA::Resource::OLease))      
      a3 = manager.find_lease({:name => 'l1'}, auth)
      a3.reload
      a1.should == a3
    end

    it 'throws exception when looking for non-exisiting lease' do
      lambda do 
        manager.find_lease({:name => 'l1'}, auth)
      end.should raise_error(UnavailableResourceException)
    end
    
    it "can request all user's leases" do

      auth.should_receive(:can_create_account?)
      a1 = manager.find_or_create_account({:name => 'a1'}, auth)

      manager.find_all_leases_for_account(a1, auth).should == []   

      auth.should_receive(:can_create_lease?)
      l1 = manager.find_or_create_lease({:name => 'l1', :account => a1}, auth)
      
      auth.should_receive(:can_view_lease?)      
      manager.find_all_leases_for_account(a1, auth).should == [l1]
      
      auth.should_receive(:can_create_lease?)
      l2 = manager.find_or_create_lease({:name => 'l2', :account => a1}, auth)
       
      auth.should_receive(:can_view_lease?).exactly(2).times
      manager.find_all_leases_for_account(a1, auth).should == [l1, l2]

      auth.should_receive(:can_view_lease?).exactly(2).times.and_raise(InsufficientPrivilegesException)    
      manager.find_all_leases_for_account(a1, auth).should == []
    end
    
    it 'can modify leases' do
      auth.should_receive(:can_create_lease?)
      l1 = manager.find_or_create_lease({:name => 'l1'}, auth)

      valid_from = 1338847200
      valid_until = 1338850800
      auth.should_receive(:can_modify_lease?).with(l1)            
      l2 = manager.modify_lease({:name => 'l1', :valid_from => valid_from, :valid_until => valid_until}, l1, auth)
      l2.save
      l2.should == l1.reload
      l2.valid_from.should == valid_from
      l2.valid_until.should == valid_until
    end
    
    it 'can cancel a lease' do
      auth.should_receive(:can_create_lease?)
      l1 = manager.find_or_create_lease({:name => 'l1'}, auth)
      
      auth.should_receive(:can_cancel_lease?).with(l1)   
      manager.cancel_lease(l1, auth)#.should be_true
    end

  end # context - lease

  context 'resource' do
    let(:account) { OMF::SFA::Resource::OAccount.new(:name => 'a') }
    let(:auth) do
      auth = double('authorizer') 
      auth.stub(:account) { account }
      auth    
    end
  #  let (:manager) { AMManager.new }
    

    before :each do
      DataMapper.auto_migrate! # reset database
      @r1 = OMF::SFA::Resource::OResource.new(:name => 'r1')
      @r2 = OMF::SFA::Resource::OResource.new(:name => 'r2')
      manager.manage_resources([@r1, @r2])
    end
    
    it 'find single resource belonging to anyone' do
      auth.should_receive(:can_view_resource?).with(kind_of(OMF::SFA::Resource::OResource)) 
      r = manager.find_resource({:name => 'r1'}, auth)
      r.should be_a(OMF::SFA::Resource::OResource)   
    end
    
    it 'find single resource belonging to account' do
      account = OMF::SFA::Resource::OAccount.new(:name => 'a')
      auth.stub(:account) { account }

      # resources belong to nil account, so they shouldn't be found
      lambda do      
        manager.find_resource_for_account({:name => 'r1'}, auth)
      end.should raise_error(UnknownResourceException)
      
      # now, assign them to this account
      @r1.account = account
      @r1.save
      auth.should_receive(:can_view_resource?).with(@r1)      
      r = manager.find_resource_for_account({:name => 'r1'}, auth)
      r.should == @r1
    end
    
    it 'will create resource if not already available for the account' do
      account = OMF::SFA::Resource::OAccount.new(:name => 'a')
      auth.stub(:account) { account }
      
      vr = OMF::SFA::Resource::OResource.new(:name => 'v1')
      vr.should be_a(OMF::SFA::Resource::OResource)
      scheduler.stub(:create_resource).and_return(vr)
      scheduler.create_resource().should == vr

      descr = {:name => 'r1'}
      auth.should_receive(:can_create_resource?) #.with(descr, 'oresource')
      #auth.should_receive(:can_view_resource?)
      r = manager.find_or_create_resource_for_account(descr, 'oresource', auth)
      r.should == vr
    end
    
    it 'will create resource from rspec' do
      rspec = %{
        <rspec xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1" type="request">
          <node component_name="r1">
            <available now="true"/>
          </node>
        </rspec>
      } 
      req = Nokogiri.XML(rspec)
      
      vr = OMF::SFA::Resource::Node.new(:name => 'vn')
      # vr.stub(:group?).and_return(false)
      # vr.stub(:save)
      # vr.should_receive(:create_from_xml)
      scheduler.stub(:create_resource) do |resource_descr, type_to_create, authorizer|
        resource_descr[:name].should == 'r1'
        authorizer.should == auth
        vr
      end
      auth.should_receive(:can_create_resource?).with({:name => 'r1', :account => account}, anything)  
      #auth.should_receive(:can_view_resource?)          
      r = manager.update_resources_from_rspec(req.root, true, auth)
      r.should == [vr]
    end
    
  end # context - resource
  
end
