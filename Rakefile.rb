

require 'rubygems'
# require 'spec/rake/spectask'
#  
# Spec::Rake::SpecTask.new(:spec) do |t|
  # t.spec_files = Dir.glob('spec/**/*_spec.rb')
  # t.spec_opts << '--format specdoc'
  # t.rcov = true
# end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  sfad = File.dirname(__FILE__)
  t.ruby_opts = "-I #{sfad}/ruby -I #{sfad}/../omf-common/ruby"
  #t.rspec_opts = '-f d'  # explains what has been tested
end

task :default => :spec