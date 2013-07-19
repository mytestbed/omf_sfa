
REQUIRE_LOGIN = false

#MyRunner.instance.init_data_mapper

require 'rack/file'
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end
end

opts = OMF::Common::Thin::Runner.instance.options

require 'omf-sfa/am/am-rest/session_authenticator'
use OMF::SFA::AM::Rest::SessionAuthenticator, #:expire_after => 10,
          :login_url => (REQUIRE_LOGIN ? '/login' : nil),
          :no_session => ['^/$', '^/login', '^/logout', '^/readme', '^/assets']

#use ::Rack::Lint

require 'omf-sfa/resource/oresource'
OMF::SFA::Resource::OResource.href_resolver do |res, o|
  unless @http_prefix ||=
    @http_prefix = "http://#{Thread.current[:http_host]}"
  end
  case res.resource_type.to_sym
  when :account
    "#@http_prefix/accounts/#{res.uuid}"
  else
    "#@http_prefix/resources/#{res.uuid}"
  end
end

map '/accounts' do
  require 'omf-sfa/am/am-rest/account_handler'
  run OMF::SFA::AM::Rest::AccountHandler.new(opts)
end

map '/slices' do
  require 'omf-sfa/am/am-rest/account_handler'
  run opts[:account_handler]
end

map "/resources" do
  require 'omf-sfa/am/am-rest/resource_handler'
  #account = opts[:am_mgr].get_default_account()
  run OMF::SFA::AM::Rest::ResourceHandler.new(opts)
end

map "/" do
    require 'bluecloth'
    s = File::read(File.dirname(__FILE__) + '/REST_API.md')
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
    return [200, {"Content-Type" => "text/html"}, wrapper % frag]
  end
  run p
end

map '/assets' do
  run MyFile.new(File.dirname(__FILE__) + '/../../../../share/assets')
end
