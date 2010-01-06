require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'logger'
require 'rack/cache'
describe "Components for RestClient" do
  before(:each) do
    RestClient.reset
    @mock_304_net_http_response = mock('http response', :code => 304, :body => "body", :to_hash => {"Date"=>["Mon, 04 Jan 2010 13:42:43 GMT"], 'header1' => ['value1', 'value2']})
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
  end
  
  it "should automatically have the Compatibility component enabled" do
    RestClient.components.first.should == [RestClient::Rack::Compatibility]
  end
  it "should enable components" do
    RestClient.enable Rack::Cache, :key => "value"
    RestClient.enabled?(Rack::Cache).should be_true
    RestClient.components.first.should == [Rack::Cache, [{:key => "value"}]]
    RestClient.enable Rack::CommonLogger
    RestClient.components.length.should == 3
    RestClient.components.first.should == [Rack::CommonLogger, []]
  end
  
  describe "usage" do
    before do

      @expected_args = {:url=>"http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b", :method=>:get, :headers=>{:additional_header=>"whatever"}}
      @expected_request = RestClient::Request.new(@expected_args)
    end
    
    describe "internal" do
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
    
    describe "external" do
      before do
        RestClient.enable Rack::Cache, :key => "value"
        @rack_app = RestClient::RACK_APP
        @rack_app_after_cache = Rack::Cache.new(@rack_app)
        @rack_app_after_composition = RestClient::Rack::Compatibility.new(@rack_app_after_cache)
        RestClient::Request.should_receive(:new).once.with(@expected_args).and_return(@expected_request)
        Rack::Cache.should_receive(:new).with(@rack_app, :key => "value").and_return(@rack_app_after_cache)
      end
      
      it "should pass through the components [using RestClient::Resource instance methods]" do
        RestClient::Rack::Compatibility.should_receive(:new).with(@rack_app_after_cache).and_return(@rack_app_after_composition)
        resource = RestClient::Resource.new('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b')
        @rack_app_after_composition.should_receive(:call).with( 
          hash_including( {'HTTP_ADDITIONAL_HEADER' => 'whatever', "restclient.request" => @expected_request }) 
        )
        resource.get(:additional_header=>"whatever")
      end
      
      it "should pass through the components [using RestClient class methods]" do
        RestClient::Rack::Compatibility.should_receive(:new).with(@rack_app_after_cache).and_return(@rack_app_after_composition)
        @rack_app_after_composition.should_receive(:call).with( 
          hash_including( {'HTTP_ADDITIONAL_HEADER' => 'whatever', "restclient.request" => @expected_request }) 
        )
        RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
      end

      it "should return a RestClient response" do
        RestClient::Rack::Compatibility.should_receive(:new).with(@rack_app_after_cache).and_return(@rack_app_after_composition)
        @rack_app.should_receive(:call).and_return(
          [200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]]
        )
        response = RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
        response.should be_a(RestClient::Response)
        response.code.should == 200
        response.headers.should == {:content_type=>"text/plain", :x_rack_cache=>"miss", :content_length=>"13", :allow => "GET, POST", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}
        response.to_s.should == "response body"
      end
      
      it "should return a response following the rack spec, if the compatibility component is disabled" do
        RestClient.disable RestClient::Rack::Compatibility
        @rack_app.should_receive(:call).and_return(
          [200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]]
        )
        response = RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
        response.should be_a(Array)
        code, header, body = response
        code.should == 200
        header.should == {"X-Rack-Cache"=>"miss", "Date"=>"Mon, 04 Jan 2010 13:37:18 GMT", "Content-Type"=>"text/plain", "Content-Length"=>"13", "Allow"=>"GET, POST"}
        body.should == ["response body"]
      end
    end
    
    describe "RestClient Exceptions" do
      before do
        RestClient::Request.should_receive(:new).once.with(@expected_args).and_return(@expected_request)
        @mock_resource_not_found_net_http_response = mock("net http response", :code => 404, :to_hash => {'header1' => ['value1']}, :body => "Not Found")
      end
      describe "with compatibility component" do
        it "should still raise the RestClient exceptions" do
          @expected_request.should_receive(:original_execute).and_raise(RestClient::Exception.new("error"))
          lambda{ RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')}.should raise_error(RestClient::Exception)
        end
        it "should still raise the RestClient exceptions with message" do
          @expected_request.should_receive(:original_execute).and_raise(RestClient::ResourceNotFound.new(@mock_resource_not_found_net_http_response))
          lambda{ RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')}.should raise_error(RestClient::ResourceNotFound)
        end
      end
      describe "without compatibility component" do
        it "should still raise the RestClient high-level exceptions" do
          RestClient.components.clear
          @expected_request.should_receive(:original_execute).and_raise(RestClient::Exception.new("error"))
          lambda{ RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')}.should raise_error(RestClient::Exception)
        end
        it "should not raise the RestClient exceptions with response" do
          RestClient.components.clear
          @expected_request.should_receive(:original_execute).and_raise(RestClient::ResourceNotFound.new(@mock_resource_not_found_net_http_response))
          response = RestClient.get('http://domain.tld:8888/some/cacheable/resource?q1=a&q2=b', :additional_header => 'whatever')
          response.should be_a(Array)
        end
      end
    end

  end
  
  describe RestClient::Rack::Compatibility do
    it "should transform a Rack response into a RestClient Response" do
      fake_app = Proc.new{|env|
        [200, {"Content-Type" => "text/plain", "Content-Length" => "13", "Allow" => "GET, POST", "Date" => "Mon, 04 Jan 2010 13:37:18 GMT"}, ["response body"]]
      }
      response = RestClient::Rack::Compatibility.new(fake_app).call(@env)
      response.should be_a(RestClient::Response)
      response.code.should == 200
      response.headers.should == {:content_type=>"text/plain", :content_length=>"13", :allow => "GET, POST", :date => "Mon, 04 Jan 2010 13:37:18 GMT"}
      response.to_s.should == "response body"
    end
    it "should raise RestClient Exceptions if restclient.error exists" do
      fake_app = Proc.new{|env|
        raise RestClient::Exception, "error"
      }
      lambda{RestClient::Rack::Compatibility.new(fake_app).call(@env)}.should raise_error(RestClient::Exception)
    end
  end
end
