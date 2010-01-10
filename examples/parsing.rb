# In this example, we automatically parse the response body if the Content-Type looks like JSON
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'json'

module Rack
  class JSON
    def initialize app
      @app = app
    end
    
    def call(env)
      status, header, body = @app.call env
      content = ""
      body.each{|line| content << line}
      parsed_body = ::JSON.parse content if header['Content-Type'] =~ /^application\/.*json/i
      [status, header, parsed_body]
    end
  end
end

RestClient.disable RestClient::Rack::Compatibility
# this breaks the Rack spec, but it should be the last component to be enabled.
RestClient.enable Rack::JSON

status, header, parsed_body = RestClient.get "http://twitter.com/statuses/user_timeline/20191563.json"
p parsed_body.map{|tweet| tweet['text']}
