require "#{File.dirname(__FILE__)}/common"

require 'omf-sfa/am/am-rest/resource_group_handler'
require 'omf-sfa/resource/node'
require 'omf-sfa/resource/group_component'

include OMF::SFA::Resource
include OMF::SFA::AM

describe 'ResourceGroup handler' do
  before :all do
    init_dm
  end
  
  before :each do
    @h = ResourceGroupHandler.new
    @req = MockRequest.new(:path => '/slices/foo')
  end

  
  it 'can list empty group' do
    g = GroupComponent.create(:name => 'foo')
    g.save
    
    res = @h.on_get(g, :req => @req)
    exp = {:group_response => {
              :about => "/slices/foo",
              'uuid' => g.uuid.to_s,     
              "href" => "/slices/foo", 
              "sfa_class" => "group",
              "component_name" => "foo", 
              "component_manager_id" => "authority+am", 
              "component_id" => "urn:publicid:IDN+mytestbed.net+group+foo", 
              "components" => []
          }}
    res.should == exp
  end
  
  it 'can list with node and interface' do
    g = GroupComponent.create(:name => 'foo')
    g.contains_resources << (n = Node.create(:name => 'n1'))
    n.interfaces << (if1 = Interface.create(:name => 'if1'))
    g.save
    
    res = @h.on_get(g, :req => @req)
    exp = {:group_response => {
              :about => "/slices/foo",
              'uuid' => g.uuid.to_s,    
              "href" => "/slices/foo", 
              "sfa_class" => "group",
              "component_name" => "foo", 
              "component_manager_id" => "authority+am", 
              "component_id" => "urn:publicid:IDN+mytestbed.net+group+foo", 
              "components" => [{
                "href" => "/slices/resources/n1",
                "uuid"=> n.uuid.to_s,
                "sfa_class"=>"node",
                "component_name"=>"n1",
                "component_manager_id"=>"authority+am",
                "component_id"=>"urn:publicid:IDN+mytestbed.net+node+n1",
                "available" => "true",
                "interfaces" => [{
                  "href" => "/slices/resources/if1",
                  "uuid" => if1.uuid.to_s,
                  "component_name" => "if1",
                  "component_manager_id" => "authority+am",
                  "component_id" => "urn:publicid:IDN+mytestbed.net+interface+if1",
                  "sfa_class" => "interface"
                }]
              }]
          }}
    res.should == exp
  end

  it 'can create a group on put' do
    root = GroupComponent.create(:name => 'root')
    
    b = '<group component_id="urn:publicid:IDN+mytestbed.net+group+g1"/>'
    opts = create_def_opts(:path => '/slices/foo/resources/r3', :body => b)
    
    res = @h.on_put(root.name, opts)
    res.should == { :resource_response => {
      :about => "/slices/foo/resources/r3", 
      "href" => "/slices/foo/resources/r3", 
      "available" => "true", 
      "uuid" => r3.uuid.to_s, 
      "component_name" => "r3", 
      "component_manager_id" => "authority+am", 
      "component_id" => "urn:publicid:IDN+mytestbed.net+node+r3", 
      "sfa_class" => "node",
      "interfaces" => []
    }}
  end
  

end

