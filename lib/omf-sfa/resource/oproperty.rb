require 'omf-sfa/resource/oresource'
require 'json'
require 'time'
require 'omf_base/lobject'

# We use the JSON serialization for Time objecs from 'json/add/core' in order to avoid
# the conflicts with the 'active_support/core_ext' which is included in 'omf_base'
# and overrides Time objects serialization. We want 'JSON.load' to return actual Time
# objects instead of Strings.
#
class Time
  def to_json(*args)
    {
      JSON.create_id => self.class.name,
      's' => tv_sec,
      'n' => respond_to?(:tv_nsec) ? tv_nsec : tv_usec * 1000
    }.to_json(*args)
  end

  def self.json_create(object)
    if usec = object.delete('u') # used to be tv_usec -> tv_nsec
      object['n'] = usec * 1000
    end
    if instance_methods.include?(:tv_nsec)
      at(object['s'], Rational(object['n'], 1000))
    else
      at(object['s'], object['n'] / 1000)
    end
  end
end

#raise "JSON deserialisation no longer working - require 'json' early" unless JSON.load(Time.now.to_json).is_a? Time

module OMF::SFA::Resource

  # Each resource will have a few properties.
  #
  #
  class OProperty < OMF::Base::LObject
    include DataMapper::Resource
    property :id,   Serial

    property :name, String
    property :type, String, length: 2
    property :s_value, String # actually serialized Object
    property :n_value, Float

    belongs_to :o_resource

    # module ArrayProxy
      # def << (val)
        # if @on_set_block
          # val = @on_set_block.call(val)
          # return if val.nil?
        # end
        # @oproperty << val
        # @on_modified_block.call(val, true) if @on_add_block
        # super
      # end
#
      # def clear()
        # _remove { super }
      # end
#
      # def delete(obj)
        # _remove { super }
      # end
#
      # def delete_at(index)
        # _remove { super }
      # end
#
      # def delete_if(&block)
        # _remove { super }
      # end
#
      # # Callback to support 'reverse' operation
      # def on_modified(&block)
        # @on_modified_block = block
      # end
#
      # def on_set(&block)
        # @on_set_block = block
      # end
#
      # private
      # def _remove(&block)
        # old = self.dup
        # r = block.call()
        # removed = old - self
        # unless removed.empty?
          # if @on_remove_block
            # removed.each {|it| @on_modified_block.call(it, false) }
          # end
          # @oproperty.value = self
        # end
        # r
      # end
    # end

    def self.prop_all(query, opts = {}, resource_class = nil)
      i = 0
      where = query.map do |pn, v|
        h = _analyse_value(v)
        tbl = "p#{i}"
        i += 1
        if (val = h[:v]).is_a? String
          val = "'#{val}'"
        end
        "#{tbl}.#{h[:f]} #{h[:t] == 's' ? 'LIKE' : '='} #{val}"
      end
      i.times do |j|
        where << "r.id = p#{j}.o_resource_id"
      end
      where << "r.type = '#{resource_class}'" if resource_class

      table = storage_names[:default]
      from = i.times.map {|j| "#{table} AS p#{j}" }
      from << "omf_sfa_resource_o_resources AS r" # TODO: Shouldn't hard-code that
      q = "SELECT DISTINCT r.id, r.type, r.uuid, r.name FROM #{from.join(', ')} WHERE #{where.join(' AND ')};"
      if l = opts[:limit]
        q += " LIMIT #{l} OFFSET #{opts[:offset] || 0}"
      end
      debug "prop_all q: #{q}"
      res = repository(:default).adapter.select(q)
      ores = res.map do |qr|
        if resource_class
          resource_class.first(id: qr.id, uuid: qr.uuid, name: qr.name) # TODO: Does this create a DB call?
        else
          _create_resource(qr)
        end
      end
      #puts "RES>>> #{ores}"
      ores
    end

    @@name2class = {}
    def self._create_resource(query_result)
      qr = query_result
      unless klass = @@name2class[qr.type]
        begin
        klass = qr.type.split('::').inject(Object) do |mod, class_name|
          mod.const_get(class_name)
        end
        rescue Exception => ex
          warn "Can't find class '#{qr.type}' for resource - #{ex}"
          return nil
        end
        @@name2class[qr.type] = klass
      end
      klass.first(id: qr.id, uuid: qr.uuid, name: qr.name) # TODO: Does this create a DB call?
    end

    def value=(val)
      h = self.class._analyse_value(val)
      attribute_set(h[:f], h[:v])
      attribute_set(:type, h[:t])
      save
    end

      # if val.is_a? Numeric
        # attribute_set(:n_value, val)
        # attribute_set(:type, (val.is_a? Integer) ? 'i' : 'f')
      # elsif val.is_a? String
        # attribute_set(:s_value, val)
        # attribute_set(:type, 's')
      # elsif val.is_a? OResource
        # attribute_set(:s_value, val.uuid.to_s)
        # attribute_set(:type, 'r')
      # elsif val.is_a? Time
        # attribute_set(:n_value, val.to_i)
        # attribute_set(:type, 't')
      # else
        # puts "OOOOO INSETRT (#{attribute_get(:name)})> #{val.class}"
        # attribute_set(:s_value, JSON.generate([val]))
        # attribute_set(:type, 'o')
      # end
      # save
    # end

    def self._analyse_value(val)

      if val.is_a? Numeric
        return {v: val, t: ((val.is_a? Integer) ? 'i' : 'f'), f: :n_value}
      elsif val.is_a? String
        return {v: val, t: 's', f: :s_value}
      elsif val.is_a? Symbol
        return {v: val.to_s, t: 's', f: :s_value}
      elsif val.is_a? OResource
        return {v: val.uuid.to_s, t: 'r', f: :s_value}
      elsif val.is_a? Time
        return {v: val.to_i, t: 't', f: :n_value}
      elsif val.class.included_modules.include?(DataMapper::Resource)
        #puts "SET>>>>> #{val}:#{val.class}"
        return {v: "#{val.class}@#{val.id}", t: 'd', f: :s_value}
      else
        #debug "SETTING VALUE>  Class: #{val.class}"
        return {v: JSON.generate([val]), t: 'o', f: :s_value}
      end
    end

    def value()
      case type = attribute_get(:type)
      when 'i'
        val =  attribute_get(:n_value).to_i
      when 'f'
        val =  attribute_get(:n_value)
      when 's'
        val = attribute_get(:s_value)
      when 'r'
        uuid = attribute_get(:s_value)
        val = OResource.first(uuid: uuid)
      when 't'
        val = Time.at(attribute_get(:n_value))
      when 'd'
        v = attribute_get(:s_value)
        klass_s, id_s = v.split('@')
        klass = klass_s.split('::').inject(Kernel) {|k, s| k.const_get(s) }
        val = klass.first(id: id_s.to_i)
        #puts "GET>>>>> #{v} - #{val}"
      when 'o'
        js = attribute_get(:s_value)
        #debug "GET VALUE>  <#{js}>"
        # http://www.ruby-lang.org/en/news/2013/02/22/json-dos-cve-2013-0269/
        val = JSON.load(js)[0]
        #puts "VALUE: #{js.inspect}-#{val.inspect}-#{val.class}"
        if val.kind_of? Array
          val.tap {|v| v.extend(ArrayProxy).instance_variable_set(:@oproperty, self) }
        end
      else
        throw "Unknown property type '#{type}'"
      end
      return val
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

     def to_hash
      {name: self.name, value: self.value}
    end

     def to_json(*args)
      to_hash.to_json(*args)
    end

    def to_s()
      "#<#{self.class} id: #{self.id} subj: #{self.o_resource} name: #{self.name} value: #{self.value}>"
    end

    #before :save do
    #  #puts "SAVING BEFORE @value_dirty:'#{@value_dirty}', @old_value_:'#{@old_value_}', @value_:'#{@value_}'"
    #  begin
    #    if @value_dirty || (@old_value_ ? @old_value_ != @value_ : false)
    #      attribute_set(:value, JSON.generate([@value_]))
    #      @value_dirty = false
    #    end
    #  rescue Exception => ex
    #    puts ">>>>>>>>> ERROR #{ex}"
    #  end
    #  #puts "SAVING AFTER @value_dirty:'#{@value_dirty}', @old_value_:'#{@old_value_}', @value_:'#{@value_}'"
    #end

  end # OProperty

  class OPropertyArray
    def <<(val)
      #puts ">>> Adding #{val} to #{@name} - #{@on_set_block}"
      p = OProperty.create(name: @name, o_resource: @resource)
      if @on_set_block
        val = @on_set_block.call(val)
        return if val.nil? #
      end
      p.value = val
      self
    end

    # Delete all members
    def clear
      OProperty.all(name: @name, o_resource: @resource).destroy
      self
    end

    [:each, :each_with_index, :select, :map].each do |n|
      define_method n do |&block|
        #c = OProperty.all(name: @name, o_resource: @resource)
        c = self.to_a()
        c.send(n, &block)
      end
    end

    def empty?
      OProperty.count(name: @name, o_resource: @resource) == 0
    end

    # Callback to support 'reverse' operation
    def on_modified(&block)
      raise "Not implemented"
      #@on_modified_block = block
    end

    def on_set(&block)
      @on_set_block = block
    end

    def to_a
      OProperty.all(name: @name, o_resource: @resource).all.map {|p| p.value }
    end

    def to_json(*args)
      OProperty.all(name: @name, o_resource: @resource).map do |p|
        p.value
      end.to_json(*args)
    end

    def to_s
      "<#{self.class}: name=#{@name} resource=#{@resource.name || @resource.uuid} >"
    end

    def initialize(resource, name)
      @resource = resource
      @name = name
    end
  end

end # OMF::SFA::Resource
