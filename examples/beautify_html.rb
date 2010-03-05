# this examples uses Rack::Tidy to automatically tidy the HTML responses returned
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'rack/tidy' # gem install rack-tidy

URL = "http://coderack.org/users/webficient/entries/38-racktidy"
puts "Without rack-tidy"
response = RestClient.get URL
puts response

puts "With rack-tidy"
RestClient.enable Rack::Tidy

response = RestClient.get URL
puts response
