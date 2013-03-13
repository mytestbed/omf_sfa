
require 'equivalent-xml'

require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/group_component'

include OMF::SFA::Resource

class TComp < OComponent
  sfa_class 'T'
end

class TComp2 < TComp
  oproperty :available, Boolean, :default => true
  sfa_class 'T2'  
  sfa :available #, :attr_value => 'now'
end 



describe OComponent do
  before :all do
    init_dm
  end

  before :each do
    GURN.clear_cache
  end
  
  it 'can create a basic component' do
    OComponent.create()
  end

  it 'can destroy a basic component' do
    OComponent.create().destroy
  end

  it 'has default domain' do
    c = OComponent.create
    c.domain.should == OComponent.default_domain
  end

  it 'has default domain' do
    c = OComponent.create(:domain => 'the_domain')
    c.domain.should == 'the_domain'
  end  

  it 'can be sfa-xml serialised' do
    c = TComp.create(:name => :foo)
    assert_sfa_xml c,%{<T %s id="#{c.uuid}" 
	      omf:href="/resources/#{c.uuid}"
	      component_id="urn:publicid:IDN+mytestbed.net+T+#{c.uuid}" 
	      component_manager_id="authority+am"
	      component_name="foo"/>}
  end

	      it 'can have simple attributes' do
		c = TComp2.create(:name => :foo)
		c.to_sfa_hash().should == {
		  "href" => "/resources/#{c.uuid}", "uuid" => c.uuid.to_s, 
		  "sfa_class" => "T2",
		    "component_name" => "foo", "component_manager_id" => "authority+am", 
		    "component_id" => "urn:publicid:IDN+mytestbed.net+T2+#{c.uuid}",
		  "available" => "true"
		}
		assert_sfa_xml c, %{
	    <T2 %s
		id="#{c.uuid}" 
		  omf:href="/resources/#{c.uuid}"
		component_id="urn:publicid:IDN+mytestbed.net+T2+#{c.uuid}" 
		component_manager_id="authority+am" 
		component_name="foo">
	      <available>true</available>
	    </T2>}
  end

  it 'can have group components' do
    g = GroupComponent.create(:name => 'g')
    g.to_sfa_hash().should == {
      "href" => "/resources/#{g.uuid}", "uuid" => g.uuid.to_s, 
      "sfa_class" => "group",
	"component_name" => "g", "component_manager_id" => "authority+am", 
	"component_id" => "urn:publicid:IDN+mytestbed.net+group+#{g.uuid}",
      "components" => []
    }

    g.to_hash.should == {:name => "g", :type=>"group", :uuid=>"#{g.uuid}", :href=>"/resources/#{g.uuid}", :resources => []}
    assert_sfa_xml g, %{
	      <group %s 
		  id="#{g.uuid}"
		  omf:href="/resources/#{g.uuid}"
		  component_id="urn:publicid:IDN+mytestbed.net+group+#{g.uuid}" 
		  component_manager_id="authority+am" 
		  component_name="g">
		<components/>
	      </group>                  
    }
  end

  it 'can have group components holding components' do
    g = GroupComponent.create(:name => 'g')
    g.contains_resources << (n = TComp.create(:name => 'n'))

    g.to_hash.should == {
      :name=>"g", 
      :uuid => g.uuid.to_s,
      :type=> "group", 
      :href=> "/resources/#{g.uuid}", 
      :resources => [{
        :name => "n", 
        :type => "T", 
        :status=>"unknown", 
        :domain => "mytestbed.net", 
        :uuid => n.uuid.to_s,
        :href=> "/resources/#{n.uuid}", 
      }]
    }
    g.to_sfa_hash().should == {
      "href" => "/resources/#{g.uuid}", "uuid" => g.uuid.to_s, "sfa_class" => "group",
      "component_name" => "g", "component_manager_id" => "authority+am", 
      "component_id" => "urn:publicid:IDN+mytestbed.net+group+#{g.uuid}",
      "components" => [{
        "href" => "/resources/#{n.uuid}",
        "uuid" => n.uuid.to_s,
        "component_name" => "n",
        "component_manager_id" => "authority+am",
        "component_id" => "urn:publicid:IDN+mytestbed.net+T+#{n.uuid}",
        "sfa_class" => "T"
      }]
    }
    assert_sfa_xml g, %{
        <group %s
      id="#{g.uuid}"
      omf:href="/resources/#{g.uuid}"
      component_id="urn:publicid:IDN+mytestbed.net+group+#{g.uuid}" 
      component_manager_id="authority+am" component_name="g">
    <components>
      <T 
        id="#{n.uuid}" 
        omf:href="/resources/#{n.uuid}"
        component_id="urn:publicid:IDN+mytestbed.net+T+#{n.uuid}" 
        component_manager_id="authority+am" 
        component_name="n"/>
    </components>
        </group>                  
    }
  end

  it 'can have group components holding other groups' do
    g = GroupComponent.create(:name => 'g')
    g.contains_resources << (g2 = GroupComponent.create(:name => 'g2'))

    g.to_hash.should == {
      :name => "g", 
      :type => "group", 
      :uuid => g.uuid.to_s, 
      :href => "/resources/#{g.uuid}",      
      :resources => [{
  :name => "g2", 
  :type => "group", 
  :href => "/resources/#{g2.uuid}",        
  :resources => [], 
  :uuid => g2.uuid.to_s
      }]
    }
    g.to_sfa_hash().should == {
    "component_name" => "g", 
    "component_manager_id" => "authority+am", 
    "href" => "/resources/#{g.uuid}", 
    "uuid" => g.uuid.to_s,
    "sfa_class" => "group",
    "component_id" => "urn:publicid:IDN+mytestbed.net+group+#{g.uuid}",
    "components" => [{
      "component_name" => "g2",
      "href" => "/resources/#{g2.uuid}",
      "uuid" => g2.uuid.to_s,
      "sfa_class" => "group",
      "component_manager_id" => "authority+am",
      "component_id" => "urn:publicid:IDN+mytestbed.net+group+#{g2.uuid}",
      "components" => []
    }]
    }


    assert_sfa_xml g, %{
        <group %s
      id="#{g.uuid}" 
      omf:href="/resources/#{g.uuid}"
      component_id="urn:publicid:IDN+mytestbed.net+group+#{g.uuid}" 
      component_manager_id="authority+am" component_name="g">
    <components>
      <group 
        id="#{g2.uuid}" 
        omf:href="/resources/#{g2.uuid}"
        component_id="urn:publicid:IDN+mytestbed.net+group+#{g2.uuid}" 
        component_manager_id="authority+am" 
        component_name="g2">
        <components/>
      </group>
    </components>
        </group>                  
    }
  end

  end

