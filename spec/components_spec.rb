require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'logger'
require 'rack/cache'
describe "Components for RestClient" do
    
  it "should enable components" do
    RestClient.components.clear
    RestClient.enable Rack::Cache, :key => "value"
    RestClient.enabled?(Rack::Cache).should be_true
    RestClient.components.first.should == [Rack::Cache, [{:key => "value"}]]
    RestClient.enable Rack::CommonLogger
    RestClient.components.length.should == 2
  end
  
  describe "correctly instantiated" do
    before do
      RestClient.components.clear
      RestClient.enable Rack::Cache, :key => "value"
      @mock_304_net_http_response = mock('http response', :code => 304, :to_s => "body", :to_hash => {"Date"=>["Mon, 04 Jan 2010 13:42:43 GMT"], 'header1' => ['value1', 'value2']})
      @env = {
        'REQUEST_METHOD' => 'GET',
        "SCRIPT_NAME" => '/some/cacheable',
        "PATH_INFO" => '/resource',
        "QUERY_STRING" => 'q1=a&q2=b',
        "SERVER_NAME" => 'domain.tld',
        "SERVER_PORT" => '8888',
        "rack.version" => Rack::VERSION,
        "rack.run_once" => false,
        "rack.multithread" => true,
        "rack.multiprocess" => true,
        "rack.url_scheme" => "http",
        "rack.input" => StringIO.new,
        "rack.errors" => $stderr
      }
      @expected_args = {:url=>"http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b", :method=>:get, :headers=>{:additional_header=>"whatever"}}
      @expected_request = RestClient::Request.new(@expected_args)
    end
    
    it "should pass through the cache [using RestClient::Resource instance methods]" do
      resource = RestClient::Resource.new('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b')
      RestClient::Request.should_receive(:new).once.with(@expected_args).and_return(@expected_request)
      Rack::Cache.should_receive(:new).with(RestClient::RACK_APP, :key => "value").and_return(app = mock("rack app"))
      app.should_receive(:call).with( 
        hash_including( {'HTTP_ADDITIONAL_HEADER' => 'whatever', "restclient.request" => @expected_request }) 
      ).and_return([200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]])
      response = resource.get(:additional_header => 'whatever')
      response.should be_a(RestClient::Response)
      response.code.should == 200
      response.headers.should == {:content_type=>"text/plain", :content_length=>"13", :allow => "GET, POST", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}
      response.to_s.should == "response body"
    end
    
    it "should pass through the cache [using RestClient class methods]" do
      RestClient::Request.should_receive(:new).once.with(@expected_args).and_return(@expected_request)
      Rack::Cache.should_receive(:new).with(RestClient::RACK_APP, :key => "value").and_return(app = mock("rack app"))
      app.should_receive(:call).with( 
        hash_including( {'HTTP_ADDITIONAL_HEADER' => 'whatever', "restclient.request" => @expected_request}) 
      ).and_return([200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]])
      response = RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
      response.should be_a(RestClient::Response)
      response.code.should == 200
      response.headers.should == {:content_type=>"text/plain", :content_length=>"13", :allow => "GET, POST", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}
      response.to_s.should == "response body"
    end
  
    it "should allow for mutiple components and execute them in the right order" do
      RestClient.enable Rack::CommonLogger, STDOUT
      RestClient::Request.should_receive(:new).once.with(@expected_args).and_return(@expected_request)
      app = mock("rack app")
      app2 = mock("rack app2")
      Rack::Cache.should_receive(:new).with(RestClient::RACK_APP, :key => "value").and_return(app)
      Rack::CommonLogger.should_receive(:new).with(app, STDOUT).and_return(app2)
      app2.should_receive(:call).with( 
        hash_including( {'HTTP_ADDITIONAL_HEADER' => 'whatever', "restclient.request" => @expected_request}) 
      ).and_return([200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]])
      response = RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
      response.should be_a(RestClient::Response)
      response.code.should == 200
      response.headers.should == {:content_type=>"text/plain", :content_length=>"13", :allow => "GET, POST", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}
      response.to_s.should == "response body"
    end
    
    it "should call the backend (bypassing the cache) if the requested resource is not in the cache" do
      @expected_request.should_receive(:original_execute).and_return(
        mock('rest-client response', 
          :headers => {:content_type => "text/plain, */*", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}, 
          :code => 200, 
          :to_s => 'body'))
      status, header, body = Rack::Lint.new(Rack::CommonLogger.new(Rack::Cache.new(RestClient::RACK_APP))).call(@env.merge(
        'restclient.request' => @expected_request
      ))
      status.should == 200
      header.should == {"content-type"=>"text/plain, */*", "X-Rack-Cache"=>"miss", "date"=>"Mon, 04 Jan 2010 13:37:18 GMT"}
      content = ""
      body.each{|part| content << part}
      content.should == "body"
    end
    
    it "should return a 304 not modified response if the call to the backend returned a 304 not modified response" do
      @expected_request.should_receive(:original_execute).and_raise(RestClient::NotModified.new(@mock_304_net_http_response))
      status, header, body = Rack::Lint.new(Rack::Cache.new(RestClient::RACK_APP)).call(@env.merge(
        'restclient.request' => @expected_request
      ))
      status.should == 304
      header.should == {"X-Rack-Cache"=>"miss", "date"=>"Mon, 04 Jan 2010 13:42:43 GMT", "header1"=>"value1"} # restclient only returns the first member of each header
      content = ""
      body.each{|part| content<<part}
      content.should == "body"
    end
  end
end
