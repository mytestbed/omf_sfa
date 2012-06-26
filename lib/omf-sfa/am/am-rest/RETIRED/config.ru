require 'omf-sfa/am/am-rest/sliver_handler' 
require 'omf-sfa/am/am-rest/def_sliver_handler' 

# Adding an 'href' attribute to every component
#
require 'omf-sfa/resource/component'
module FixComponent
  def self.included(base)
    base.class_eval do
      sfa :href, :attribute => true
      
      def href
        if kind_of? OMF::SFA::Resource::Sliver
          "/slices/#{self.name}"
        else
          if self.sliver == OMF::SFA::Resource::Sliver.def_sliver
            "/resources/#{self.name}"
          else            
            "/slices/#{self.sliver.name}/resources/#{self.name}"
          end
        end
      end
    end
  end
end

OMF::SFA::Resource::Component.uses.each do |k|
  k.class_eval "include FixComponent"
end

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

map "/slivers" do
  run OMF::SFA::AM::SliverHandler.new(opts)
end

map "/resources" do
  run OMF::SFA::AM::DefaultSliverHandler.new(opts)
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
