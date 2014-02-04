

#RPC_URL = '/rpc'
RPC_URL = '/RPC2'

REQUIRE_LOGIN = false

require 'rack/file'
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end
end


# There seem to be some issues with teh sfi.py tool
#use Rack::Lint

#am_mgr = opts[:am][:manager]
#sleep 10
opts = OMF::Base::Thin::Runner.instance.options
#puts self.methods.sort.inspect
am_mgr = opts[:am][:manager]
if am_mgr.is_a? Proc
  am_mgr = am_mgr.call()
end

require 'omf-sfa/am/am-rest/session_authenticator'
use OMF::SFA::AM::Rest::SessionAuthenticator, #:expire_after => 10,
          :login_url => (REQUIRE_LOGIN ? '/login' : nil),
          :no_session => ['^/$', "^#{RPC_URL}", '^/login', '^/logout', '^/readme', '^/assets']


map RPC_URL do
  require 'omf-sfa/am/am-rpc/am_rpc_service'
  service = OMF::SFA::AM::RPC::AMService.new({:manager => am_mgr, :liaison => opts[:am][:liaison]})

  app = lambda do |env|
    [404, {"Content-Type" => "text/plain"}, ["Not found"]]
  end

  run Rack::RPC::Endpoint.new(app, service, :path => '')
end

map '/slices' do
  require 'omf-sfa/am/am-rest/account_handler'
  run OMF::SFA::AM::Rest::AccountHandler.new(opts[:am][:manager], opts)
end


map "/resources" do
  require 'omf-sfa/am/am-rest/resource_handler'
  # account = opts[:am_mgr].get_default_account()  # TODO: Is this still needed?
  # run OMF::SFA::AM::Rest::ResourceHandler.new(opts[:am][:manager], opts.merge({:account => account}))
    run OMF::SFA::AM::Rest::ResourceHandler.new(opts[:am][:manager], opts)
end

if REQUIRE_LOGIN
  map '/login' do
    require 'omf-sfa/am/am-rest/login_handler'
    run OMF::SFA::AM::Rest::LoginHandler.new(opts[:am][:manager], opts)
  end
end

map "/readme" do
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

    return [200, {"Content-Type" => "text/html"}, [wrapper % frag]]
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../../share/assets')
end

map "/" do
  handler = Proc.new do |env|
    req = ::Rack::Request.new(env)
    case req.path_info
    when '/'
      [301, {'Location' => '/readme', "Content-Type" => ""}, ['Next window!']]
    when '/favicon.ico'
      [301, {'Location' => '/assets/image/favicon.ico', "Content-Type" => ""}, ['Next window!']]
    else
      OMF::Base::Loggable.logger('rack').warn "Can't handle request '#{req.path_info}'"
      [401, {"Content-Type" => ""}, "Sorry!"]
    end
  end
  run handler
end

