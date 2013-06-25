
module OMF::SFA::Resource
  module Constants
    
    @@default_domain = "omf:nitos"
    @@default_component_manager_id = GURN.create("authority+am").to_s
    
    def self.default_domain=(dname)
      @@default_domain = dname
    end   
    
    def self.default_domain()
      @@default_domain
    end   
    
    def self.default_component_manager_id=(gurn)
      @@default_component_manager_id = GURN.create(gurn).to_s 
    end   

    def self.default_component_manager_id()
      @@default_component_manager_id
    end
  end
end
