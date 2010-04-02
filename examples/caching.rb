require 'restclient/components'
require 'rack/cache'
require 'json'
require 'logger'
require 'time'
require 'digest/sha1'
require 'sinatra/base'


def server(base=Sinatra::Base, &block)
  app = Sinatra.new(base, &block)
  pid = fork do
    app.run!(:port => 7890, :host => "localhost")
  end  
  pid
end

pid = server do
  RESOURCE = {
    :updated_at => Time.at(Time.now-2),
    :content => "hello"
  }
  get '/cacheable/resource' do
    response['Cache-Control'] = "public, max-age=4"
    last_modified RESOURCE[:updated_at].httpdate
    etag Digest::SHA1.hexdigest(RESOURCE[:content])
    RESOURCE[:content]
  end
  
  put '/cacheable/resource' do
    RESOURCE[:content] = params[:content]
    RESOURCE[:updated_at] = Time.now
    response['Location'] = '/cacheable/resource'
    "ok"
  end
end

RestClient.enable Rack::CommonLogger
RestClient.enable Rack::Cache, :verbose => true, :allow_reload => true, :allow_revalidate => true
RestClient.enable Rack::Lint

begin
  puts "Manipulating cacheable resource..."
  6.times do
    sleep 1
    RestClient.get "http://localhost:7890/cacheable/resource" do |response|
      p [response.code, response.headers[:etag], response.headers[:last_modified], response.to_s]
    end
  end
  sleep 1
  RestClient.put "http://localhost:7890/cacheable/resource", {:content => "world"} do |response|
    p [response.code, response.headers[:etag], response.headers[:last_modified], response.to_s]
  end
  # note how the cache is automatically invalidated on non-GET requests
  2.times do
    sleep 1
    RestClient.get "http://localhost:7890/cacheable/resource" do |response|
      p [response.code, response.headers[:etag], response.headers[:last_modified], response.to_s]
    end
  end
rescue RestClient::Exception => e
  p [:error, e.message]
ensure
  Process.kill("INT", pid)
  Process.wait
end

__END__
Manipulating cacheable resource...
== Sinatra/0.9.4 has taken the stage on 7890 for development with backup from Thin
>> Thin web server (v1.2.5 codename This Is Not A Web Server)
>> Maximum connections set to 1024
>> Listening on localhost:7890, CTRL+C to stop
cache: [GET /cacheable/resource] miss, store
- - - [15/Feb/2010 22:37:27] "GET /cacheable/resource " 200 5 0.0117
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [GET /cacheable/resource] fresh
- - - [15/Feb/2010 22:37:28] "GET /cacheable/resource " 200 5 0.0022
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [GET /cacheable/resource] fresh
- - - [15/Feb/2010 22:37:29] "GET /cacheable/resource " 200 5 0.0017
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [GET /cacheable/resource] fresh
- - - [15/Feb/2010 22:37:30] "GET /cacheable/resource " 200 5 0.0019
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [GET /cacheable/resource] stale, valid, store
- - - [15/Feb/2010 22:37:31] "GET /cacheable/resource " 200 5 0.0074
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [GET /cacheable/resource] fresh
- - - [15/Feb/2010 22:37:32] "GET /cacheable/resource " 200 5 0.0017
[200, "\"aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d\"", "Mon, 15 Feb 2010 21:37:24 GMT", "hello"]
cache: [PUT /cacheable/resource] invalidate, pass
- - - [15/Feb/2010 22:37:33] "PUT /cacheable/resource " 200 2 0.0068
[200, nil, nil, "ok"]
cache: [GET /cacheable/resource] stale, invalid, store
- - - [15/Feb/2010 22:37:34] "GET /cacheable/resource " 200 5 0.0083
[200, "\"7c211433f02071597741e6ff5a8ea34789abbf43\"", "Mon, 15 Feb 2010 21:37:33 GMT", "world"]
cache: [GET /cacheable/resource] fresh
- - - [15/Feb/2010 22:37:35] "GET /cacheable/resource " 200 5 0.0017
[200, "\"7c211433f02071597741e6ff5a8ea34789abbf43\"", "Mon, 15 Feb 2010 21:37:33 GMT", "world"]
>> Stopping ...

== Sinatra has ended his set (crowd applauds)
