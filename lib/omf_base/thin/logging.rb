require 'omf_base/lobject'

module Thin
  # Overwrite thin's logging mix-in to work more nicely 
  # with log4r
  #
  module Logging
    class << self
      attr_writer :trace, :debug, :silent
      
      def trace?;  !@silent && @trace  end
      def debug?;  !@silent && @debug  end
      def silent?;  @silent            end
    end
    
    # # Global silencer methods
    # def silent
      # Logging.silent?
    # end
    # def silent=(value)
      # Logging.silent = value
    # end
    
    # Log a message to the console
    def log(msg)
      (@logger ||= OMF::Base::LObject.new(self.class)).info(msg)
    end
    module_function :log
    public :log
    
    # Log a message to the console if tracing is activated
    def trace(msg=nil)
      return unless msg      
      (@logger ||= OMF::Base::LObject.new(self.class)).debug(msg)
    end
    module_function :trace
    public :trace
    
    # Log a message to the console if debugging is activated
    def debug(msg=nil)
      return unless msg
      (@logger ||= OMF::Base::LObject.new(self.class)).debug(msg)
    end
    module_function :debug
    public :debug
    
    # Log an error backtrace if debugging is activated
    def log_error(e = $!)
      (@logger ||= OMF::Base::LObject.new(self.class)).error(e)
    end
    module_function :log_error
    public :log_error
  end
end
