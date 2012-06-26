require 'omf-sfa/resource/oresource'
require 'json'

module OMF::SFA::Resource
  
  # Each resource will have a few properties.
  #
  #
  class OProperty
    include DataMapper::Resource
    property :id,   Serial    

    property :name, String
    property :value, String # actually serialized Object
      
    belongs_to :o_resource
    
    def value=(val)
      return if @value_ == val
      @value_ = val
      @value = 'dummy'
      @value_dirty = true
    end 

    def value()
      unless @value_
        js = attribute_get(:value)
        if js
          @value_ = JSON.parse(js)[0]
          if @value_.kind_of? Array
            @old_value_ = @value_.dup
          end
        end
      end
      #puts "GET #{@value_.inspect}"      
      @value_
    end
    
    def valid?(context = :default)
      self.name != nil #&& self.value != nil
    end
    
    # alias_method :_dirty_attributes, :dirty_attributes
    # def dirty_attributes
      # dirty = _dirty_attributes
      # #puts "DIRTY ATTRIBUTE #{dirty.inspect}"
      # dirty
    # end
    
    alias_method :_dirty_self?, :dirty_self?
    def dirty_self?
      #puts "#{object_id} DIRTY CHECK #{@value_dirty}"
      return true if @value_dirty || _dirty_self?
      if @old_value_ 
        return @old_value_ != @value_
      end
      false
    end

    before :save do
      #puts "SAVING BEFORE '#{self.inspect}"      
      begin
        if @value_dirty || (@old_value_ ? @old_value_ != @value_ : false)
          attribute_set(:value, JSON.generate([@value_]))
          @value_dirty = false
        end
      rescue Exception => ex
        puts ">>>>>>>>> ERROR #{ex}"
      end
      #puts "SAVING '#{@value_.inspect}'::#{self.inspect}"      
    end      
    
  end # OProperty
  
end # OMF::SFA::Resource