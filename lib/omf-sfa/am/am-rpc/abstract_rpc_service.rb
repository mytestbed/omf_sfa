

require 'xmlrpc/parser'
require 'rack/rpc'  

require 'omf_common/lobject'

require 'omf-sfa/am'

module OMF::SFA::AM
  module RPC; end
end

module OMF::SFA::AM::RPC
  
  class AbstractService < Rack::RPC::Server

    include OMF::Common::Loggable

    # This defines a method to declare the service methods and all their 
    # parameters.
    #
    def self.implement(api)
      @@mappings ||= {}
      api.api_description.each do |m|
        wrapper_name = "_wrapper_#{m.method_name}".to_sym
        self.send(:define_method, wrapper_name) do |*args|
          begin
            self.class.hooks[:before].each do |command| 
              command.call(self) if command.callable?(m.method_name)
            end
            
            out = self.send(m.method_name, *args)
            
            self.class.hooks[:after].each do |command| 
              command.call(self) if command.callable?(m.method_name)
            end
            out
          rescue Exception => ex
            error ex
            debug "Backtrace\n\t#{ex.backtrace.join("\n\t")}"
            raise ex
          end
        end
        #puts "API: map #{m.rpc_name} to #{wrapper_name}"
        @@mappings[m.rpc_name.to_s] = wrapper_name
      end
    end
    
    def self.rpc(mappings = nil)
      raise "Unexpected argument '#{mappings}' for rpc" if mappings
      @@mappings
    end
  end # AbstractService
  
  
end # module



