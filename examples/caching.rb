# In this example, https://localhost:3443/sid/grid5000/sites/grenoble/jobs is a resource having an Expires header, that makes it cacheable.
# Note how POSTing a payload to this resource automatically invalidates the previously cached entry.
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'rack/cache'
require 'json'
require 'zlib'
RestClient.log = 'stdout'
RestClient.enable Rack::Cache, :allow_reload => true, :allow_revalidate => true

api = RestClient::Resource.new('https://localhost:3443')
def get_jobs(api, headers={})
  puts "*** GETting jobs..."
  jobs = JSON.parse api['/sid/grid5000/sites/grenoble/jobs'].get({:accept => :json}.merge(headers))
end

begin
  puts "Number of jobs=#{get_jobs(api)['items'].length}" 
  puts "Number of jobs=#{get_jobs(api)['items'].length}" 
  puts "*** POSTing new job"
  job = {
    :resources => "nodes=1",
    :command => "sleep 120"
  }
  api['/sid/grid5000/sites/grenoble/jobs'].post(job.to_json, :content_type => :json, :accept => :json) 
  puts "Number of jobs=#{get_jobs(api)['items'].length}"
rescue RestClient::Exception => e
  if e.respond_to?(:response)
    p e.response.to_hash
    p Zlib::GzipReader.new(StringIO.new(e.response.body)).read
  else
    p e.message
  end
end

__END__
This example displays:
*** GETting jobs...
RestClient.get "https://localhost:3443/sid/grid5000/sites/grenoble/jobs", headers: {"Accept-encoding"=>"gzip, deflate", "Accept"=>"application/json"}
# => 200 OK | application/json 295 bytes
cache: [GET /sid/grid5000/sites/grenoble/jobs] miss
Number of jobs=1
*** GETting jobs...
cache: [GET /sid/grid5000/sites/grenoble/jobs] fresh
Number of jobs=1
*** POSTing new job
RestClient.post "https://localhost:3443/sid/grid5000/sites/grenoble/jobs", headers: {"Accept-encoding"=>"gzip, deflate", "Content-type"=>"application/json", "Content-Length"=>"45", "Accept"=>"application/json"}, paylod: "{\"resources\":\"nodes=1\",\"command\":\"sleep 120\"}"
# => 201 Created | application/json 181 bytes
cache: [POST /sid/grid5000/sites/grenoble/jobs] invalidate, pass
*** GETting jobs...
RestClient.get "https://localhost:3443/sid/grid5000/sites/grenoble/jobs", headers: {"Accept-encoding"=>"gzip, deflate", "Accept"=>"application/json"}
# => 200 OK | application/json 323 bytes
cache: [GET /sid/grid5000/sites/grenoble/jobs] miss
Number of jobs=2