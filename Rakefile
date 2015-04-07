require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "rest-client-components"
    s.summary = %Q{RestClient on steroids ! Easily add one or more Rack middleware around RestClient to add functionalities such as transparent caching (Rack::Cache), transparent logging, etc.}
    s.email = "cyril.rohr@gmail.com"
    s.homepage = "http://github.com/crohr/rest-client-components"
    s.description = "RestClient on steroids ! Easily add one or more Rack middleware around RestClient to add functionalities such as transparent caching (Rack::Cache), transparent logging, etc."
    s.authors = ["Cyril Rohr"]
    s.add_dependency "rest-client", ">= 1.6.0"
    s.add_dependency "rack", ">= 1.0.1"
    s.add_development_dependency "webmock", ">= 1.21"
    s.add_development_dependency "rspec", ">= 3.2.0"
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = 'rest-client-components'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

task :default => :spec
