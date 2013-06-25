require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/node'
require 'omf-sfa/resource/ogroup'
require 'json'

include OMF::SFA::Resource

def init_logger
  OMF::Common::Loggable.init_log 'OResource', :searchPath => File.join(File.dirname(__FILE__), 'OResource')
  #@config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../etc/omf-sfa'])[:omf_sfa_am]
end

class TA < OResource
  oproperty :flag, Boolean, :default => true
end 

class A < OResource
  oproperty :b, :B
  oproperty :ba, :B, :functional => false  
end 

class B < OResource
end 

class G < OResource
  oproperty :g, :o_group
end

describe OResource do

  init_logger

  before :each do
    init_dm
  end
  
  it 'can create a basic resource' do
    OResource.create()
  end

  it 'can destroy a basic resource' do
    OResource.create().destroy
  end

  it 'assigns a UUID by default' do  
    r = OResource.create()
    r.uuid.should_not be(nil)
  end
  
  it 'can serialize' do
    o = OResource.create()
    js = o.to_json
    o.reload
    # http://www.ruby-lang.org/en/news/2013/02/22/json-dos-cve-2013-0269/
    # alternative: o2 = JSON.load(js)
    o2 = JSON.parse(js, :create_additions => true)
    o2.uuid.should == o.uuid
  end
  
  it 'can be serialized into a hash' do
    o = OResource.create(:name => :foo)
    o.to_hash.should == {:type=>"unknown", :name=>"foo", :uuid=>"#{o.uuid.to_s}", :href => "/resources/#{o.uuid}"}   
  end
  
  
  it 'can have simple properties' do
    o = OResource.create()
    o.o_properties.create(:name => 'p1', :value => 'v1')
    o.o_properties.create(:name => 'p2', :value => 123)    
    o.save
    o.reload
    
    p = o.o_properties[0]
    p.name.should == 'p1'
    p.value.should == 'v1'

    p2 = o.o_properties[1]
    p2.name.should == 'p2'
    p2.value.should == 123
    
  end
  
  it 'can have properties pointing to other resources' do 
    o1 = OResource.create(:name => 'o1')
    o2 = OResource.create(:name => 'o2')
    u2 = o2.uuid
        
    o1.oproperties.create(:name => 'p1', :value => o2)
    o1.save
    o1.reload; o2.reload    
    
    p = o1.oproperties[0]
    v = p.value
    v.class.should == OResource
    v.uuid.should == u2
  end  
  
  it 'can have named properties as [] on resource' do
    o = OResource.create(:name => 'foobar')
    o['name'].should == 'foobar'
    
    o['foo'] = 1
    o['foo'].should == 1
    o[:foo].should == 1
    o.save
    o.reload
    o['foo'].should == 1
  end
  
  it 'can define properties with +oproperty+' do
    o = TA.create(:name => 'o')
    o.flag = true
    o.save
    
    o.reload
    o.flag.should == true
    o.to_hash.should == {:type=>"unknown", :uuid=>"#{o.uuid}", :href => "/resources/#{o.uuid}", :name => 'o', :flag => true}   
  end
  
  it 'can have properties linking to other object' do
    a = A.create(:name => 'a')
    a.b.should == nil
    a.bas.should == []    
    
    b = B.create
    a.b = b
    
    a.save
    a.reload
    
    a.b.uuid.should == b.uuid
    a.to_hash.should == {
      :type=>"unknown", :uuid=>"#{a.uuid}", :href => "/resources/#{a.uuid}", :name => 'a',
      :b => b.uuid.to_s
    }       
  end
  
  it 'can have properties linking to groups' do
    r = G.create(:name => 'r')
    g = OGroup.create(:name => 'g')
    r.g = g
    
    r.g.should == g
    r.to_hash.should == {:name => "r", :type=>"unknown", :uuid=>"#{r.uuid}", :g => g.uuid.to_s, :href => "/resources/#{r.uuid}"}
  end

  it 'can have non-functional properties' do
    a = A.create(:name => 'a')
    a.bas.should == []    
    
    a.save
    a.reload

    b = B.create
    a.bas = b
    #a.bas << b
    a.bas.should == [b]    
    a.save
    a.reload
    
    a.bas.should == [b]

    b2 = B.create
    a.bas << b2
    a.save
    a.reload

    a.bas.should == [b, b2]
    a.to_hash.should == {
      :type=>"unknown", :uuid=>"#{a.uuid}", :href=>"/resources/#{a.uuid}", :name => 'a',
      :bas => [b.uuid.to_s, b2.uuid.to_s]
    }             

    a.bas = []
    a.save
    a.reload
    a.bas.should == []
  end

  it 'returns properties as a hash' do
    a = A.create
    b = B.create
    a.bas << b
    a.b = b
    a.save
    a.reload

    a.oproperties_as_hash.should == {'b' => b, 'bas' => [b]}
  end

  it 'can have Time oproperties' do
    class Bar < OResource
    end

    class Foo < Bar
      oproperty :created_at, DataMapper::Property::Time
    end

    f = Foo.new
    f.created_at = Time.now
    f.save

    f.created_at.should be_a_kind_of(Time)
  end

end

