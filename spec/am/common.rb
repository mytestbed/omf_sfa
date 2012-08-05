
require 'omf-sfa/resource'

def init_dm
  # setup database
  DataMapper::Logger.new($stdout, :info)
  #DataMapper::Logger.new(STDOUT, :debug)
  
  DataMapper.setup(:default, 'sqlite::memory:')
  DataMapper::Model.raise_on_save_failure = true 
  DataMapper.finalize
    
  require  'dm-migrations'
  DataMapper.auto_migrate!
end

def assert_sfa_xml(resource, expected)
  doc = resource.to_sfa_xml()
  
  expected = format expected, 'xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:omf="http://schema.mytestbed.net/sfa/rspec/1"'
  exp = Nokogiri.XML(expected)
  doc.should be_equivalent_to(exp)
end