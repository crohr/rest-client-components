require 'rubygems'
require 'spec'
require 'webmock/rspec'

include WebMock
$LOAD_PATH.unshift(File.dirname(__FILE__))


Spec::Runner.configure do |config|
  
end
