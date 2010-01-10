require 'restclient'
require 'rack'

module RestClient
  module Rack
    class Compatibility
      def initialize(app)
        @app = app
      end
      
      def call(env)
        status, header, body = @app.call(env)
        if e = env['restclient.error']
          raise e
        else
          response = RestClient::MockNetHTTPResponse.new(body, status, header)
          content = ""
          response.body.each{|line| content << line}
          RestClient::Response.new(content, response)
        end
      end
    end
  end

  class <<self
    attr_reader :components
  end
  
  # Enable a Rack component. You may enable as many components as you want.
  # e.g.
  # Transparent HTTP caching:
  #   RestClient.enable Rack::Cache, 
  #                       :verbose     => true,
  #                       :metastore   => 'file:/var/cache/rack/meta'
  #                       :entitystore => 'file:/var/cache/rack/body'
  # 
  # Transparent logging of HTTP requests (commonlog format):
  #   RestClient.enable Rack::CommonLogger, STDOUT
  # 
  # Please refer to the documentation of each rack component for the list of available options.
  # 
  def self.enable(component, *args)
    # remove any existing component of the same class
    disable(component)
    @components.unshift [component, args]
  end
  
  # Disable a component
  #   RestClient.disable Rack::Cache
  #   => array of remaining components
  def self.disable(component)
    @components.delete_if{|(existing_component, options)| component == existing_component}
  end
  
  # Returns true if the given component is enabled, false otherwise
  #   RestClient.enable Rack::Cache
  #   RestClient.enabled?(Rack::Cache)
  #   => true
  def self.enabled?(component)
    !@components.detect{|(existing_component, options)| component == existing_component}.nil?
  end
  
  def self.reset
    # hash of the enabled components 
    @components = [[RestClient::Rack::Compatibility]]
  end
  
  def self.debeautify_headers(headers = {})   # :nodoc:
    headers.inject({}) do |out, (key, value)|
			out[key.to_s.gsub(/_/, '-').split("-").map{|w| w.capitalize}.join("-")] = value.to_s
			out
		end
  end
  
  reset
  
  # Reopen the RestClient::Request class to add a level of indirection in order to create the stack of Rack middleware.
  # 
	class Request
	  alias_method :original_execute, :execute
	  def execute
      uri = URI.parse(@url)
      uri_path_split = uri.path.split("/")
      path_info = (last_part = uri_path_split.pop) ? "/"+last_part : ""
      script_name = uri_path_split.join("/")
      # minimal rack spec
      env = { 
        "restclient.request" => self,
        "REQUEST_METHOD" => @method.to_s.upcase,
        "SCRIPT_NAME" => script_name,
        "PATH_INFO" => path_info,
        "QUERY_STRING" => uri.query || "",
        "SERVER_NAME" => uri.host,
        "SERVER_PORT" => uri.port.to_s,
        "rack.version" => ::Rack::VERSION,
        "rack.run_once" => false,
        "rack.multithread" => true,
        "rack.multiprocess" => true,
        "rack.url_scheme" => uri.scheme,
        "rack.input" => StringIO.new,
        "rack.errors" => $stderr   # Rack-Cache writes errors into this field
      }
      @processed_headers.each do |key, value|
        env.merge!("HTTP_"+key.to_s.gsub("-", "_").upcase => value)
      end
      stack = RestClient::RACK_APP
      RestClient.components.each do |(component, args)|
        if (args || []).empty?
          stack = component.new(stack)
        else
          stack = component.new(stack, *args)
        end
      end
      stack.call(env)
    end
  end
	
  # A class that mocks the behaviour of a Net::HTTPResponse class.
  # It is required since RestClient::Response must be initialized with a class that responds to :code and :to_hash.
  class MockNetHTTPResponse
    attr_reader :body, :header, :status
    alias_method :code, :status
    
    def initialize(body, status, header)
      @body = body
      @status = status
      @header = header
    end

    def to_hash
      @header.inject({}) {|out, (key, value)|
        # In Net::HTTP, header values are arrays
        out[key] = [value]
        out
      }
    end    
  end
  
  RACK_APP = Proc.new { |env|
    begin
      # get the original request, replace headers with those of env, and execute it
      request = env['restclient.request']
      additional_headers = env.keys.select{|k| k=~/^HTTP_/}.inject({}){|accu, k|
        accu[k.gsub("HTTP_", "")] = env[k]
        accu
      }
      request.processed_headers.replace(request.make_headers(additional_headers))
      response = request.original_execute
    rescue RestClient::ExceptionWithResponse => e  
      env['restclient.error'] = e
       # e is a Net::HTTPResponse
      response = RestClient::Response.new(e.response.body, e.response)
    end
    # to satisfy Rack::Lint
    response.headers.delete(:status)
    header = RestClient.debeautify_headers( response.headers )
    body = response.to_s
    # return the real content-length since RestClient does not do it when decoding gzip responses
    header['Content-Length'] = body.length.to_s if header.has_key?('Content-Length')
    [response.code, header, [body]]
  }

end
