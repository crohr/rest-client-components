require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/../lib/restclient/components'
require 'logger'
require 'rack/cache'
require 'time'
describe "Components for RestClient" do
  before(:each) do
    RestClient.reset
  end
  
  it "should automatically have the Compatibility component enabled" do
    RestClient.components.last.should == [RestClient::Rack::Compatibility]
  end
  it "should enable components" do
    RestClient.enable Rack::Cache, :key => "value"
    RestClient.enabled?(Rack::Cache).should be_truthy
    RestClient.components.first.should == [Rack::Cache, [{:key => "value"}]]
    RestClient.enable Rack::CommonLogger
    RestClient.components.length.should == 3
    RestClient.components.first.should == [Rack::CommonLogger, []]
    RestClient.components.last.should == [RestClient::Rack::Compatibility]
  end
  
  it "should allow to disable components" do
    RestClient.enable Rack::Cache, :key => "value"
    RestClient.disable RestClient::Rack::Compatibility
    RestClient.components.length.should == 1
    RestClient.components.first.should == [Rack::Cache, [{:key => "value"}]]
  end
  
  it "should always put the RestClient::Rack::Compatibility component last on the stack" do
    RestClient.enable Rack::Cache, :key => "value"
    RestClient.disable RestClient::Rack::Compatibility
    RestClient.enable RestClient::Rack::Compatibility
    RestClient.components.last.should == [RestClient::Rack::Compatibility, []]
  end
  
  describe "with Compatibility component" do
    before do
      RestClient.enable RestClient::Rack::Compatibility
      RestClient.enable Rack::Lint
    end
    it "should work with blocks" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Length' => 4, 'Content-Type' => 'text/plain'})
      lambda{ RestClient.get "http://server.ltd/resource" do |response|
        raise Exception.new(response.code)
      end}.should raise_error(Exception, "200")
    end
    it "should correctly use the response.return! helper" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 404, :body => "body", :headers => {'Content-Length' => 4, 'Content-Type' => 'text/plain'})      
      lambda{ RestClient.get "http://server.ltd/resource" do |response|
        response.return!
      end}.should raise_error(RestClient::ResourceNotFound)
    end
    it "should raise ExceptionWithResponse errors" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 404, :body => "body", :headers => {'Content-Length' => 4, 'Content-Type' => 'text/plain'})
      lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ResourceNotFound)
    end
    it "should raise Exception errors" do
      stub_request(:get, "http://server.ltd/resource").to_raise(EOFError)
      lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ServerBrokeConnection)
    end
    it "should raise timeout Exception errors" do
      stub_request(:get, "http://server.ltd/resource").to_raise(Timeout::Error)
      lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::RequestTimeout)
    end
    it "should correctly pass the payload in rack.input" do
      class RackAppThatProcessesPayload
        def initialize(app); @app = app; end
        def call(env)
          env['rack.input'].rewind
          env['rack.input'] = StringIO.new(env['rack.input'].read.gsub(/rest-client/, "<b>rest-client-components</b>"))
          env['CONTENT_TYPE'] = "text/html"
          @app.call(env)
        end
      end
      RestClient.enable RackAppThatProcessesPayload
      stub_request(:post, "http://server.ltd/resource").with(:body => "<b>rest-client-components</b> is cool", :headers => {'Content-Type'=>'text/html', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'37', 'Accept'=>'*/*; q=0.5, application/xml'}).to_return(:status => 201, :body => "ok", :headers => {'Content-Length' => 2, 'Content-Type' => "text/plain"})
      RestClient.post "http://server.ltd/resource", 'rest-client is cool', :content_type => "text/plain"
    end
    
    it "should correctly pass content-length and content-type headers" do
      stub_request(:post, "http://server.ltd/resource").with(:body => "some stupid message", :headers => {'Content-Type'=>'text/plain', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'19', 'Accept'=>'*/*; q=0.5, application/xml'}).to_return(:status => 201, :body => "ok", :headers => {'Content-Length' => 2, 'Content-Type' => "text/plain"})
      RestClient.post "http://server.ltd/resource", 'some stupid message', :content_type => "text/plain", :content_length => 19
    end
    
    describe "and another component" do
      before do
        class AnotherRackMiddleware
          def initialize(app); @app=app; end
          def call(env)
            env['HTTP_X_SPECIFIC_HEADER'] = 'value'
            @app.call(env)
          end
        end
        RestClient.enable AnotherRackMiddleware
      end
      it "should correctly pass the headers set by other components" do
        stub_request(:get, "http://server.ltd/resource").with(:headers => {'X-Specific-Header' => 'value'}).to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
        RestClient.get "http://server.ltd/resource"
      end
    end
    
    describe "with Rack::Cache enabled" do
      before(:each) do
        RestClient.enable Rack::Cache,
          :metastore   => 'heap:/1/',
          :entitystore => 'heap:/1/'
      end
      it "should raise ExceptionWithResponse errors" do
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 404, :body => "body", :headers => {'Content-Length' => 4, 'Content-Type' => 'text/plain'})
        lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ResourceNotFound)
      end
      it "should raise Exception errors" do
        stub_request(:get, "http://server.ltd/resource").to_raise(EOFError)
        lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ServerBrokeConnection)
      end
      it "should return a RestClient::Response" do
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
        RestClient.get "http://server.ltd/resource" do |response|
          response.code.should == 200
          response.headers[:x_rack_cache].should == 'miss'
          response.body.should == "body"
        end
      end
      it "should get cached" do
        now = Time.now
        last_modified = Time.at(now-3600)
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Cache-Control' => 'public', 'Content-Length' => 4, 'Date' => now.httpdate, 'Last-Modified' => last_modified.httpdate}).times(1).then.
            to_return(:status => 304, :headers => {'Content-Type' => 'text/plain', 'Cache-Control' => 'public', 'Content-Length' => 0, 'Date' => now.httpdate, 'Last-Modified' => last_modified.httpdate})
        RestClient.get "http://server.ltd/resource" do |response|
          response.headers[:x_rack_cache].should == 'miss, store'
          response.headers[:age].should == "0"
          response.body.should == "body"
        end
        RestClient.get "http://server.ltd/resource" do |response|
          response.headers[:x_rack_cache].should == 'stale, valid, store'
          response.body.should == "body"
        end
      end
    end
  end
  
  describe "without Compatibility component" do
    before do
      RestClient.disable RestClient::Rack::Compatibility
      RestClient.enable Rack::Lint
    end
    it "should return response as an array of status, headers, body" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
      lambda{RestClient.get "http://server.ltd/resource" do |response|
        raise Exception.new(response.class)
      end}.should raise_error(Exception, "Array")
    end
    it "should return response as an array of status, headers, body if response block is used" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
      status, headers, body = RestClient.get "http://server.ltd/resource"
      status.should == 200
      headers.should == {"Content-Type"=>"text/plain", "Content-Length"=>"4"}
      content = ""
      body.each{|block| content << block}
      content.should == "body"
    end
    it "should not raise ExceptionWithResponse exceptions" do
      stub_request(:get, "http://server.ltd/resource").to_return(:status => 404, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
      status, headers, body = RestClient.get "http://server.ltd/resource"
      status.should == 404
      headers.should == {"Content-Type"=>"text/plain", "Content-Length"=>"4"}
      content = ""
      body.each{|block| content << block}
      content.should == "body"
    end
    it "should still raise Exception errors" do
      stub_request(:get, "http://server.ltd/resource").to_raise(EOFError)
      lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ServerBrokeConnection)
    end
    
    describe "with Rack::Cache" do
      before do
        RestClient.enable Rack::Cache,
          :metastore   => 'heap:/2/',
          :entitystore => 'heap:/2/'
      end
      it "should not raise ExceptionWithResponse errors" do
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 404, :body => "body", :headers => {'Content-Length' => 4, 'Content-Type' => 'text/plain'})
        status, headers, body = RestClient.get "http://server.ltd/resource"
        status.should == 404
        headers['X-Rack-Cache'].should == 'miss'
        content = ""
        body.each{|block| content << block}
        content.should == "body"
      end
      it "should raise Exception errors" do
        stub_request(:get, "http://server.ltd/resource").to_raise(EOFError)
        lambda{ RestClient.get "http://server.ltd/resource" }.should raise_error(RestClient::ServerBrokeConnection)
      end
      it "should return an array" do
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Content-Length' => 4})
        RestClient.get "http://server.ltd/resource" do |response|
          status, headers, body = response
          status.should == 200
          headers['X-Rack-Cache'].should == 'miss'
          content = ""
          body.each{|block| content << block}
          content.should == "body"
        end
      end
      it "should get cached" do
        now = Time.now
        last_modified = Time.at(now-3600)
        stub_request(:get, "http://server.ltd/resource").to_return(:status => 200, :body => "body", :headers => {'Content-Type' => 'text/plain', 'Cache-Control' => 'public', 'Content-Length' => 4, 'Date' => now.httpdate, 'Last-Modified' => last_modified.httpdate}).times(1).then.
            to_return(:status => 304, :headers => {'Content-Type' => 'text/plain', 'Cache-Control' => 'public', 'Content-Length' => 0, 'Date' => now.httpdate, 'Last-Modified' => last_modified.httpdate})
        RestClient.get "http://server.ltd/resource" do |status, headers, body|
          headers['X-Rack-Cache'] == 'miss, store'
          headers['Age'].should == "0"
        end
        sleep 1
        RestClient.get "http://server.ltd/resource" do |status, headers, body|
          headers['X-Rack-Cache'].should == 'stale, valid, store'
          headers['Age'].should == "1"
        end
      end
    end
  end
  
end
