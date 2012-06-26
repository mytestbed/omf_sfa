
require 'omf-sfa/resource/abstract_resource'

module OMF::SFA::Resource
  
  module Component 
    @@uses_component = []
    
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
    
    def self.included(base)
      @@uses_component << base
      base.class_eval do
        
        #### ABSTRACT
        property :name, String
    
        # managing dm objct
        property :id,   DataMapper::Property::Serial
    
        alias :name_ name
        def name
          unless name = name_
            c = sfa_class
            count = self.class.count
            if c
              name =  "#{c}#{count}"
            else
              name = "#{self.class.to_s.downcase}#{count}"
            end
            self.name = name
          end
          name      
        end
        #### ABSTRACT
        
  
        property :domain, String #, readonly => true
        property :exclusive, DataMapper::Property::Boolean
    
        sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'
        
        sfa :component_id, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
        sfa :component_manager_id, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
        sfa :component_name, :attribute => true # "plane
        sfa :exclusive, :is_attribute => true #="false"> 
    
    
        before :save do
          #puts ">>>> BEFORE SAVE: #{self.inspect}"
          # if self.name.nil?
            # self.name = "c#{Component.count}"
          # end
          if self.domain.nil?
            self.domain = Component.default_domain
          end
          # if self.sliver.nil?
            # self.sliver = Sliver.def_sliver
          # end
        end
        
        def component_id
          @component_id ||= GURN.create(self.component_name, self)
        end
        
        def component_manager_id
          @component_manager_id ||= (Component.default_component_manager_id ||= GURN.create("authority+am"))
        end
    
        def component_name
          self.name
        end

      end
    end
      
    def self.first(*args)
      @@uses_component.each do |c|
        begin
          f = c.first(*args)
          return f if f
        rescue ArgumentError => ex
          #puts "COMPONET FIND (#{c})>>>> #{ex}"
          #puts ex.backtrace.join("\n")
          # ignore errors related to certain properties not found
        end
      end
      nil
    end
    
    # Return an array of classes using the Component mix-in
    #
    def self.uses
      @@uses_component
    end

  end  # Component
end # OMF::SFA::Resource