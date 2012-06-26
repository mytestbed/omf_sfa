

module OMF::SFA::Resource
  
  # Provides a many-to-many relationship 
  # between resources and groups
  #
  class GroupMembership
    include DataMapper::Resource

    belongs_to :o_resource
    belongs_to :o_group
    #has n, :groups
    
    property :id,   Serial    
  end
end