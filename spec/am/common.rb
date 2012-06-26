
require "#{File.dirname(__FILE__)}/../resource/common"
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ogroup'
require 'omf-sfa/resource/ocomponent'
require 'json'

class MockRequest
  def initialize(opts = {})
    @opts = opts
  end
  
  def []=(k, v)
    @opts[k] = v
  end
  
  def [](k)
    @opts[k]
  end
  
  def method_missing(name, *args, &block)
    return @opts[name]
  end
end

def create_def_opts(ropts = {})
  req = MockRequest.new(ropts)
  {:req => req} #, :am_mgr => @mgr}
end
