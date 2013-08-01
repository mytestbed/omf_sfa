

require 'log4r/outputter/fileoutputter'

module Log4r
  # When daemonizing, the file handler gets closed and we fall over here. 
  # The following monkey patch retries once to open the file and write again
  #
  class FileOutputter
    
    # def initialize(_name, hash={})
      # raise "#{_name}::#{hash.inspect}"
    # end
    
    def write(data)
      #puts ">>> #{data}"
      begin
        @out.print data
        @out.flush
      rescue IOError => ioe # recover from this instead of crash
        # retry once
        unless @retrying
          @retrying = true
          @out = File.new(@filename, (@trunc ? "w" : "a"))
          return write(data)
        end
        Logger.log_internal {"IOError in Outputter '#{@name}'!"}
        Logger.log_internal {ioe}
        close
      rescue NameError => ne
        Logger.log_internal {"Outputter '#{@name}' IO is #{@out.class}!"}
        Logger.log_internal {ne}
        close
      end
      @retrying = false
    end      
  end
end

# module OMF; module Common; end end
# 
# #
# # An extended object class with support for logging
# #
# module OMF::Base
  # module Log4r
#     
    # class DateFileOutputter < ::Log4r::DateFileOutputter
#       
      # def write(data)
        # puts ">>> #{data}"
        # begin
          # @out.print data
          # @out.flush
        # rescue IOError => ioe # recover from this instead of crash
          # Logger.log_internal {"IOError in Outputter '#{@name}'!"}
          # Logger.log_internal {ioe}
          # close
        # rescue NameError => ne
          # Logger.log_internal {"Outputter '#{@name}' IO is #{@out.class}!"}
          # Logger.log_internal {ne}
          # close
        # end
      # end      
    # end
  # end
# end
# 
# puts "REQUIRE #{OMF::Base::Log4r::DateFileOutputter}"
