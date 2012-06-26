require 'equivalent-xml'

require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/node'


include OMF::SFA::Resource

describe Node do
  before :all do
    init_dm
  end
  
  it 'can create a node' do
    Node.create()
  end
  
  it 'can serialize a simple node' do
    n = Node.create(:name => 'n1')
    assert_sfa_xml n, %{
      <node %s 
          id="#{n.uuid}" 
          omf:href="/resources/#{n.uuid}"
          component_id="urn:publicid:IDN+mytestbed.net+node+n1" 
          component_manager_id="authority+am" 
          component_name="n1">
        <available now="true"/>
      </node>
    }
  end
  
  it 'can have an interface' do
    n = Node.create(:name => 'n1')
    n.interfaces << (if1 = Interface.create(:name => 'if1'))
    
    assert_sfa_xml n, %{
      <node %s 
          id="#{n.uuid}" 
          omf:href="/resources/#{n.uuid}"
          component_id="urn:publicid:IDN+mytestbed.net+node+n1" 
          component_manager_id="authority+am" 
          component_name="n1">
        <available now="true"/>
        <interface 
            id="#{if1.uuid}" 
            omf:href="/resources/#{if1.uuid}"
            component_id="urn:publicid:IDN+mytestbed.net+interface+if1" 
            component_manager_id="authority+am" 
            component_name="if1"
        />
      </node>
    }
  end
  
  it 'can have multiples interface' do
    n = Node.create(:name => 'n1')
    n.interfaces << (if1 = Interface.create(:name => 'if1'))
    n.interfaces << (if2 = Interface.create(:name => 'if2'))    
    
    n.to_sfa_hash().should == {
      "href" => "/n1", "uuid" => n.uuid.to_s, "sfa_class" => "node",
      "component_name" => "n1", "component_manager_id" => "authority+am", 
      "component_id" => "urn:publicid:IDN+mytestbed.net+node+n1",
      "available" => "true",
      "interfaces" => [{
        "href" => "/if1",
        "uuid" => if1.uuid.to_s,
        "sfa_class" => "interface",
        "component_name" => "if1",
        "component_manager_id" => "authority+am",
        "component_id" => "urn:publicid:IDN+mytestbed.net+interface+if1",
      }, {
        "href" => "/if2",
        "uuid" => if2.uuid.to_s,
        "sfa_class" => "interface",
        "component_name" => "if2",
        "component_manager_id" => "authority+am",
        "component_id" => "urn:publicid:IDN+mytestbed.net+interface+if2",
      }]
    }

    assert_sfa_xml n, %{
      <node %s 
          id="#{n.uuid}" 
          omf:href="/resources/#{n.uuid}"
          component_id="urn:publicid:IDN+mytestbed.net+node+n1" 
          component_manager_id="authority+am" 
          component_name="n1">
        <available now="true"/>
        <interface 
            id="#{if1.uuid}" 
            omf:href="/resources/#{if1.uuid}"
            component_id="urn:publicid:IDN+mytestbed.net+interface+if1" 
            component_manager_id="authority+am" 
            component_name="if1"
        />
        <interface 
            id="#{if2.uuid}" 
            omf:href="/resources/#{if2.uuid}"
            component_id="urn:publicid:IDN+mytestbed.net+interface+if2" 
            component_manager_id="authority+am" 
            component_name="if2"
        />
      </node>
    }
    # doc = Nokogiri::XML::Document.new
    # n.to_sfa_xml(doc)
#     
    # exp = Nokogiri.XML(%{
            # <node 
                # id="#{n.sfa_id}" 
                # component_id="urn:publicid:IDN+mytestbed.net+node+n1" 
                # component_manager_id="authority+am" 
                # component_name="n1">
              # <available now="true"/>
              # <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+if1"/>
              # <interface_ref component_id="urn:publicid:IDN+mytestbed.net+interface+if2"/>
            # </node>})
    # doc.should be_equivalent_to(exp)    
  end  
  
  it 'can have multiples identical interface' do
    n = Node.create(:name => 'n1')
    n.interfaces << (if1 = Interface.create(:name => 'if1'))
    n.interfaces << if1
    
    n.to_sfa_hash().should == {
      "href" => "/n1", "uuid" => n.uuid.to_s, "sfa_class" => "node",
      "component_name" => "n1", "component_manager_id" => "authority+am", 
      "component_id" => "urn:publicid:IDN+mytestbed.net+node+n1",
      "available" => "true",
      "interfaces" => [{
        "href" => "/if1",
        "uuid" => if1.uuid.to_s,
        "sfa_class" => "interface",
        "component_name" => "if1",
        "component_manager_id" => "authority+am",
        "component_id" => "urn:publicid:IDN+mytestbed.net+interface+if1",
      }, {
        "href" => "/if1",
        "uuid" => if1.uuid.to_s
      }]
    }
    
    assert_sfa_xml n, %{
      <node %s 
          id="#{n.uuid}" 
          omf:href="/resources/#{n.uuid}"
          component_id="urn:publicid:IDN+mytestbed.net+node+n1" 
          component_manager_id="authority+am" 
          component_name="n1">
        <available now="true"/>
        <interface 
            id="#{if1.uuid}" 
            omf:href="/resources/#{if1.uuid}"
            component_id="urn:publicid:IDN+mytestbed.net+interface+if1" 
            component_manager_id="authority+am" 
            component_name="if1"
        />
        <interface_ref
            id_ref="#{if1.uuid}" 
            component_id="urn:publicid:IDN+mytestbed.net+interface+if1" 
        />
      </node>
    }
    
  end  
end
