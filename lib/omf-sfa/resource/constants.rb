
module OMF::SFA::Resource
  module Constants
    
    @@default_domain = "mytestbed.net"
    @@default_component_manager_id = "authority+am"
    
    def self.default_domain=(dname)
      @@default_domain = dname
    end   
    
    def self.default_domain()
      @@default_domain
    end   
    
    def self.default_component_manager_id=(gurn)
      @@default_component_manager_id = GURN.create(gurn) 
    end   

    def self.default_component_manager_id()
      @@default_component_manager_id
    end
  end
end