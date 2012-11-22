
module OMF::SFA::Resource

  # Provides a many-to-many relationship
  # between Users and Projects
  #
  class ProjectMembership 
    include DataMapper::Resource

    belongs_to :project, :key => true
    belongs_to :user, :key => true
  end 
end 
