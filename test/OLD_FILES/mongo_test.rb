require 'rubygems'
require 'data_mapper'

DataMapper.setup(:default,
  :adapter  => 'mongo',
  :database => 'my_mongo_db'
)

# Define resources
class Student
  include DataMapper::Mongo::Resource

  property :id, ObjectId
  property :name, String
  property :age, Integer
end

class Course
  include DataMapper::Mongo::Resource

  property :id, ObjectId
  property :name, String
end

# No need to (auto_)migrate!
biology = Course.create(:name => "Biology")
english = Course.create(:name => "English")

# Queries
Student.all(:age.gte => 20, :name => /oh/, :limit => 20, :order => [:age.asc])

# Array and Hash as a property
class Zoo
  include DataMapper::Mongo::Resource

  property :id, ObjectId
  property :opening_hours, Hash
  property :animals, Array
end

Zoo.create(
  :opening_hours => { :weekend => '9am-8pm', :weekdays => '11am-8pm' },
  :animals       => [ "Marty", "Alex", "Gloria" ])

Zoo.all(:animals => 'Alex')