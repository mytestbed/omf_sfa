

MyRunner.instance.init_data_mapper

require 'rack/file'
class MyFile < Rack::File
  def call(env)
    c, h, b = super
    #h['Access-Control-Allow-Origin'] = '*'
    [c, h, b]
  end  
end

use ::Rack::Lint

map '/slices' do
  require 'omf-sfa/am/am-rest/account_handler'
  run OMF::SFA::AM::AccountHandler.new(opts[:am][:manager], opts)
end


map "/resources" do
  require 'omf-sfa/am/am-rest/resource_handler'
  account = opts[:am_mgr].get_default_account()
  run OMF::SFA::AM::ResourceHandler.new(opts[:am][:manager], opts.merge({:account => account}))
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
