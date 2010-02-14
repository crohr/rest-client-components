# In this example, https://localhost:3443/sid/grid5000/sites/grenoble/jobs is a resource having an Expires header, that makes it cacheable.
# Note how POSTing a payload to this resource automatically invalidates the previously cached entry.
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'rack/cache'
require 'json'
require 'logger'
RestClient.enable Rack::CommonLogger
RestClient.enable Rack::Cache, :verbose => true, :allow_reload => true, :allow_revalidate => true

api = RestClient::Resource.new('https://localhost:3443')
def get_jobs(api, headers={})
  puts "*** GETting jobs..."
  return JSON.parse api['/sid/grid5000/sites/grenoble/jobs'].get({:accept => :json}.merge(headers))
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
  p [:error, e.response.to_s]
end

__END__