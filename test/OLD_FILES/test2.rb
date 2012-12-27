require 'rubygems'
require 'dm-core'

#include DataMapper::Types

class Root
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :type, Discriminator
end

class Branch < Root
  property :value, Integer
  property :flag, Boolean
end

#DataMapper.setup(:default, {:adapter => 'sqlite3', :database => 'test.db'})
DataMapper.setup(:default, :adapter => 'yaml', :path => '/tmp/test.yaml')
#DataMapper.auto_migrate!

branch_one = Branch.new
branch_one.name = "branch one"
branch_one.value = 42

branch_one.save

entities = Root.all

p entities
p entities[0].send(:flag)