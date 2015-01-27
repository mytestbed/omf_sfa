


module OMF::SFA
  module Util
    class UtilException < Exception; end
  end
end

module OMF::SFA::Util

  class PromiseException < UtilException
    attr_reader :promise

    def initialize(promise)
      @promise = promise
    end
  end

  class PromiseUnresolvedException < PromiseException
    attr_reader :promise, :uuid

    def initialize(promise)
      @promise = promise
    end

    def uuid
      @uuid ||= UUIDTools::UUID.random_create
    end
  end

  class PromiseAlreadySetException < PromiseException; end

  class Promise < OMF::Base::LObject

    # Returns a promise which fires when all dependencies
    def self.all(*promises)
      count = promises.length
      results = []
      new_promise = self.new()
      if count == 0
        new_promise.resolve(results)
      else
        already_rejected = false
        promises.each_with_index do |p, i|
          p.on_success do |v|
            results[i] = v
            if (count -= 1) <= 0
              new_promise.resolve(results)
            end
          end
          p.on_error do |err_code, msg|
            unless already_rejected
              already_rejected = true
              new_promise.reject(err_code, msg)
            end
          end
        end
      end
      new_promise
    end

    def value(exception_on_unresolved = PromiseUnresolvedException)
      if @status == :resolved
        @value
      else
        ex = exception_on_unresolved
        raise ex.is_a?(PromiseException) ? ex.new(self) : ex
      end
    end

    def error_msg(exception_on_unresolved = PromiseUnresolvedException)
      if @status == :rejected
        @value
      else
        ex = exception_on_unresolved
        raise ex.is_a?(PromiseException) ? ex.new(self) : ex
      end
    end

    def error_code(exception_on_unresolved = PromiseUnresolvedException)
      if @status == :rejected
        @err_code
      else
        ex = exception_on_unresolved
        raise ex.is_a?(PromiseException) ? ex.new(self) : ex
      end
    end

    # Resolve the promise.
    #
    # @param [Object] value of promise
    #
    def resolve(value)
      raise PromiseAlreadySetException.new(self) unless @status == :pending

      #puts "--------RESOLVE-#{@name}-#{@status}(#{@resolved_handlers.inspect}>>> "
      if value.is_a? self.class
        @status = :proxy
        @proxy = value
        @proxy.on_success {|v| _resolve(v)}
        @proxy.on_error {|e, m| _reject(e, m)}
      else
        _resolve(value)
      end
      self
    end

    # Resolve the promise.
    #
    # @param [Object] Reject message
    #
    def reject(err_code, msg = nil)
      unless msg
        # no error code
        msg = err_code
        err_code = 999
      end
      unless @status == :pending
        warn "No longer pending - #{self.inspect} - #{@value}"
        raise PromiseAlreadySetException.new(self)
      end
      _reject(err_code, msg)
      self
    end

    # Call block to allow modifications to the 'resolve' value
    #
    def filter(&block)
      if @filter_block
        raise "Can only define one filter block - previous #{@filter_block}"
      end
      @filter_block = block
      if @status == :resolved
        unless @resolved_handlers.empty?
          warn "Attached filter after promise was already resolved and reported to 'on_success'"
        end
        _resolve(@value)
      end
      self
    end

    # To track the progress towards resolving or rejecting the promise
    # the various tasks can report on their progress through this method.
    # Calling it with an empty message will return an array of progress
    # messages
    #
    def progress(msg = nil, timestamp = nil)
      if msg
        @progress << [timestamp ||= Time.now, msg]
        if @progress_handlers
          _call('on_progress', @progress_handlers, [timestamp, "  #{msg}"], false)
        end
      end
      @progress
    end

    # Register block to call on success, or other promise to
    # 'upcall' on success.
    #
    def on_success(other_promise = nil, &block)
      if other_promise
        raise "can't have block as well" if block
        block = lambda {|v| other_promise.resolve(v) }
      end
      if @status == :resolved
        _call('on_success', [block], [@value])
      else
        @resolved_handlers << block
      end
      self
    end

    # Register block to call on error, or other promise to
    # 'upcall' on error.
    #
    def on_error(other_promise = nil, &block)
      if other_promise
        raise "can't have block as well" if block
        block = lambda {|c, m| other_promise.reject(c, m) }
      end
      if @status == :rejected
        _call('on_error', [block], [@err_code, @value])
      else
        @rejected_handlers << block
      end
      self
    end

    # Register block to call whenever this promise transitions
    # out of 'pending'.
    #
    def on_always(&block)
      if @status == :pending
        @always_handlers << block
      else
        _call('on_always', [block], nil, false)
      end
      self
    end

    # Register block to call whenever a new progress message is being reported
    #
    def on_progress(other_promise = nil, prefix = nil, &block)
      if other_promise
        raise "can't have block as well" if block
        block = lambda do |ts, m|
          m = "  #{prefix ? "[#{prefix}]  " : ''}#{m}"
          other_promise.progress(m, ts)
        end
      end
      @progress.each do |ts, m|
        #_call('on_progress', [block], [ts, "  #{prefix ? "#{prefix}: " : ''}#{m}"], false)
        _call('on_progress', [block], [ts, m], false)
      end
      (@progress_handlers ||= []) << block
      self
    end

    def resolved?
      (@status == :proxy) ? @proxy.resolved? : (@status == :resolved)
    end

    def pending?
      (@status == :proxy) ? @proxy.pending? : (@status == :pending)
    end

    def status
      (@status == :proxy) ? @proxy.status : @status
    end

    def to_html
      case @status
      when :pending
        '.... pending'
      when :resolved
        @value.to_s
      else
        "ERROR(#{@err_code}: #{@value}"
      end
    end

    # def to_json(*a)
    #   to_str().to_json(*a)
    # end

    def to_json(*a)
      puts ">>> JSONIFY PROMISE - #{self.to_s} - #{@value}"
      if @status == :resolved
        @value.to_json(*a)
      else
        raise PromiseUnresolvedException.new(self)
      end
    end

    def to_s
      "#<#{self.class}:#{@name}-#{@status}>"
    end


    attr_reader :name

    def initialize(name = nil)
      @pretty_name = name
      @name = "p#{hash()}"
      @name += "-#{name}" if name
      @status = :pending
      @resolved_handlers = []
      @rejected_handlers = []
      @always_handlers = []
      @progress = []
      @progress_handlers = nil
      progress "#{@pretty_name} started" if @pretty_name
    end

    private

    def _resolve(value)
      @status = :resolved
      value = @filter_block.call(value) if @filter_block
      @value = value
      progress("#{@pretty_name} resolved") if @pretty_name
      _call('on_success', @resolved_handlers, [value])
      value
    end

    def _reject(err_code, msg)
      @status = :rejected
      #puts ">>>> REJECT MSG - #{msg.inspect} -- #{msg.respond_to? :pretty_print}"
      if msg.respond_to? :pretty_print
        msg = msg.pretty_print
      end
      @value = msg
      @err_code = err_code
      progress("#{@pretty_name} rejected") if @pretty_name
      _call('on_error', @rejected_handlers, [err_code, msg])
      nil
    end

    def _call(name, blocks, args, call_always_on_as_well = true)
      blocks.each do |block|
        begin
          block.call(*args)
        rescue Exception => ex
          warn "(#{@name}) Exception while calling '#{name}' - #{ex} - #{block} - #{args}"
          debug ex.backtrace.join("\n\t")
          if name == 'on_success'
            #return _call('on_error', @rejected_handlers, [-1, ex])
            # TODO: Clarify this. Currently we could have multiple
            # 'on_success' handlers, but the current logic will call
            # all 'on_error' handles if one 'on_success' throws an
            # exception and turns this promise into 'rejected'
            return _reject(-1, ex)
          end
        end
      end
      if call_always_on_as_well
        _call('on_always', @always_handlers, nil, false)
      end
    end



  end
end
