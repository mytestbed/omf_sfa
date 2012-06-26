
require "#{File.dirname(__FILE__)}/common"
require 'omf-sfa/resource/ogroup'

include OMF::SFA::Resource

describe OGroup do
  before :all do
    init_dm
    r1_id = UUIDTools::UUID.random_create
    g1_id = UUIDTools::UUID.random_create
  end
  
  before :each do
    #DataMapper.repository.delete
  end
  
  it 'can create a group' do
    OGroup.create()
  end

  it 'can contain resources' do
    g = OGroup.create()
    r = OResource.create()

    g.contains_resources << r
    g.save    
    g.reload
    r.reload
    
    g.contains_resources.size.should == 1
  end
  
  it 'should also show up on the resource side' do
    g = OGroup.create()
    gid = g.uuid
    r = OResource.create()
  
    g.contains_resources << r
    g.save    
    g.reload
    r.reload
    
    ga = r.included_in_groups
    ga.size.should == 1
    ga[0].uuid.should == gid
  end
  
  it 'can contain multiple resources' do
    g = OGroup.create()

    g.contains_resources << OResource.create()
    g.contains_resources << OResource.create()
    g.save
    g.reload
    
    g.contains_resources.size.should == 2
  end
  
  it 'can contain multiple resources and remove them' do
    g = OGroup.create()
    g.contains_resources << OResource.create(:name => 'r1')
    g.contains_resources << OResource.create()
    g.save
    g.reload
    
    g.empty_group
    g.save
    g.reload

    g.contains_resources.size.should == 0
    OResource.first(:name => 'r1').should_not == nil
  end
  
  
  it 'can contain other groups as well' do
    parent = OGroup.create(:name => :parent)
    child = OGroup.create(:name => :child)

    parent.contains_resources << child
    parent.save
    child.save
    
    parent.reload
    child.reload
    
    parent.contains_resources.size.should == 1
    child.included_in_groups.size.should == 1
    child.included_in_groups[0].name.should == 'parent'
  end

end
    