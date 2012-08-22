

#RPC_URL = '/rpc'
RPC_URL = '/RPC2'

require 'rack/file'
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end  
end

use ::Rack::Lint

#am_mgr = opts[:am][:manager]
#sleep 10
opts = OMF::SFA::AM::Runner.instance.options
#puts self.methods.sort.inspect
am_mgr = opts[:am][:manager]
if am_mgr.is_a? Proc
  am_mgr = am_mgr.call()
end

map '/slices' do
  require 'omf-sfa/am/am-rest/account_handler'
  run OMF::SFA::AM::Rest::AccountHandler.new(am_mgr, opts)
end


#map "/resources" do
#  require 'omf-sfa/am/am-rest/resource_handler'
#  account = am_mgr.get_default_account()
#  run OMF::SFA::AM::Rest::ResourceHandler.new(am_mgr, opts.merge({:account => account}))
#end

map RPC_URL do
  require 'omf-sfa/am/am-rpc/am_rpc_service'
  service = OMF::SFA::AM::RPC::AMService.new({:manager => am_mgr})
  run ::Rack::RPC::Endpoint.new(nil, service, :path => '') #:path => RPC_URL)        
end


map "/" do
  require 'bluecloth'
  s = File::read(File.dirname(__FILE__) + '/am-rest/REST_API.md')
  frag = BlueCloth.new(s).to_html
  wrapper = %{
<html>
  <head>
    <title>AM REST API</title>
    <link href="/assets/css/default.css" media="screen" rel="stylesheet" type="text/css">
    <style type="text/css">
   circle.node {
     stroke: #fff;
     stroke-width: 1.5px;
   }
      
      line.link {
        stroke: #999;
        stroke-opacity: .6;
        stroke-width: 2px;

      }
</style>
  </head>
  <body>
%s
  </body>
</html>
}
  p = lambda do |env|
  puts "#{env.inspect}"
 
    return [200, {"Content-Type" => "text/html"}, wrapper % frag] 
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../../share/assets')
end

