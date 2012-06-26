require "#{File.dirname(__FILE__)}/common"

require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/resource'

include OMF::SFA::Resource
include OMF::SFA::AM

class CompA < OComponent
  sfa_class 'compA'
end

describe 'Resource handler' do
  before :all do
    OMF::Common::Loggable.init_log 'test'
    init_dm
  end
  
  before :each do
    @mgr = DefaultManager.new
    @h = ResourceHandler.new @mgr
    @opts = create_def_opts(:path => '/slices/foo/resources/moo')
  end
  
  
  def create_node(name)
    OComponent.all(:name => name).each {|r| 
      #puts "DESTROY >>> #{r}::#{r.name}"
      r.destroy
    }
    OComponent.create(:name => name)
  end
      
  
  it 'can list basic resource' do
    r = OResource.create(:name => 'moo')
    @mgr.manage_resource(r)   
     
    exp = {:resource_response => {
             :about => "/slices/foo/resources/moo",
             :uuid => r.uuid.to_s,
             :name => "moo",
             :type => 'unknown'
          }}
    res = @h.on_get(r.uuid.to_s, @opts)
    res.should == exp
    
    res2 = @h.on_get({:name => r.name}, @opts)
    res2.should == exp
    
  end
  
  it 'can list basic components' do
    r = CompA.create(:name => 'r1')
    r.save
    @mgr.manage_resource(r)    
    
    exp = {:resource_response => {
             :about => "/slices/foo/resources/moo",
             "uuid" => r.uuid.to_s,
             "href" => "/slices/foo/resources/r1", 
             "component_name" => "r1", 
             "component_manager_id" => "authority+am", 
             "component_id" => "urn:publicid:IDN+mytestbed.net+compA+r1", 
             "sfa_class" => 'compA'
          }}
    res = @h.on_get(r.uuid.to_s, @opts)
    res.should == exp

#    res2 = @h.on_get(r.uuid.to_s, @opts)
    @mgr.manage_resource(r)
    opts = create_def_opts
    account = opts[:account] = OAccount.new()
    r.account = account
    
    res2 = @h.on_get({:name => r.component_name}, @opts)
    res2.should == exp
  end  
  
  it 'can list node with one interface' do
    n = Node.create(:name => 'n1')
    n.interfaces << (if1 = Interface.create(:name => 'if1'))
    n.save
    @mgr.manage_resource(n)
    
    res = @h.on_get(n.uuid.to_s, @opts)
    exp = {:resource_response => {
             :about => "/slices/foo/resources/moo",
             "uuid" => n.uuid.to_s,
             "href" => "/slices/foo/resources/n1", 
             'available' => "true", 
             "component_name" => "n1", 
             "component_manager_id" => "authority+am", 
             "component_id" => "urn:publicid:IDN+mytestbed.net+node+n1", 
             "sfa_class" => "node",
             "interfaces"=> [{
               "href" => "/slices/foo/resources/if1",
               "uuid" => if1.uuid.to_s,
               "component_name" => "if1",
               "component_manager_id" =>"authority+am",
               "component_id" => "urn:publicid:IDN+mytestbed.net+interface+if1",
               "sfa_class" => "interface"
             }]
          }}
    res.should == exp
  end
  
  it 'list components for various accounts' do
    OComponent.find(:name => 'r1').each {|r| r.destroy}
    r = OComponent.create(:name => 'r1')
    @mgr.manage_resource(r)
    account1 = OAccount.create()
    r.account = account1
    r.save
#    account1 = opts[:account] = OAccount.new()
    
    opts = create_def_opts(:path => '/resources/moo', :account_id => account1.uuid.to_uri)
    @mgr.get_requester_account(opts).should == account1
    
    r1h = {:name => 'r1'}
    res = @h.on_get(r1h, opts)

    account2 = OAccount.create()    
    opts = create_def_opts(:path => '/resources/moo', :account_id => UUIDTools::UUID.random_create.to_uri)
    lambda do
      res = @h.on_get(r1h, opts)
    end.should raise_error OMF::SFA::AM::UnknownAccountException
    
    opts = create_def_opts(:path => '/resources/moo', :account_id => account2.uuid.to_uri)
    lambda do
      res = @h.on_get(r1h, opts)
    end.should raise_error OMF::SFA::AM::UnknownResourceException
  end
  
  it 'can create a node on put' do
    r3 =  Node.create(:name => 'mytestbed.net+node+r3')
    r3.name.should == 'mytestbed.net+node+r3'
    @mgr.manage_resource(r3)
    r3.account.should == @mgr.get_default_account  # this test should really go somewhere else
    
    path = '/slices/foo/resources/r3'
    b = '<node component_id="urn:publicid:IDN+mytestbed.net+node+r3"/>'
    opts = create_def_opts(:path => '/slices/foo/resources/mytestbed.net+node+r3', :body => b)
    res = @h.on_put({:name => 'mytestbed.net+node+r3'}, opts)
    res.should == { :resource_response => {
      :about => "/slices/foo/resources/mytestbed.net+node+r3", 
      "href" => "/slices/foo/resources/mytestbed.net+node+r3", 
      "available" => "true", 
      "uuid" => r3.uuid.to_s, 
      "component_name" => "r3", 
      "component_manager_id" => "authority+am", 
      "component_id" => "urn:publicid:IDN+mytestbed.net+node+r3", 
      "sfa_class" => "node",
      "interfaces" => []
    }}
  end
  
  it 'can create a group on put' do
    root = OGroup.create(:name => 'root')
    @mgr.manage_resource(root)
    
    path = '/slices/foo/resources'
    b = "<group uuid='#{root.uuid}'><group name='g'/></group>"
    opts = create_def_opts(:path => path, :body => b)
    opts[:name_prefix] = path
    
    res = @h.on_put(root.uuid.to_s, opts)
    g = OMF::SFA::Resource::OGroup.first(:name => 'g')
    g.should_not nil
        
    res.should == { :resource_response => {
      :about=>"/slices/foo/resources", 
      :type=>"group",
      :href=>"/slices/foo/resources", 
      :uuid => root.uuid.to_s,
      :resources => [{
        :type=>"group", 
        :name=>"g", 
        :href=>"/slices/foo/resources/g", 
        :uuid=> g.uuid.to_s,
        :resources=>[]
      }], 
    }}     
  end
  
  it 'can delete a node on delete' do
    r = create_node('r1')
    @mgr.manage_resource(r)
    account1 = OAccount.create()
    
    opts = create_def_opts(:path => '/resources/moo', :account_id => account1.uuid.to_uri)
    res = @h.on_delete({:name => 'r1'}, opts)

    r.account = account1
    r.save
    r.account.should == account1
    opts = create_def_opts(:path => '/resources/moo', :account_id => account1.uuid.to_uri)
    @mgr.find_resource({:name => 'r1'}, opts).should == r
    
    res = @h.on_delete({:name => 'r1'}, opts)

  end
  
end