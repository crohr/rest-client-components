require 'restclient'
require 'rack'

module RestClient
  # hash of the enabled components 
  @components = []

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
    @components << [component, args]
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
  
  
  def self.debeautify_headers(headers = {})   # :nodoc:
    headers.inject({}) do |out, (key, value)|
			out[key.to_s.gsub(/_/, '-').downcase] = value.to_s
			out
		end
  end
  
  # Reopen the RestClient::Request class to add a level of indirection in order to create the stack of Rack middleware.
  # 
	class Request
	  alias_method :original_execute, :execute
	  def execute
	    unless RestClient.components.empty?
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
          "rack.version" => Rack::VERSION,
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
          if args.empty?
            stack = component.new(stack)
          else
            stack = component.new(stack, *args)
          end
        end
        status, headers, body = stack.call(env)
        response = MockNetHTTPResponse.new(body, status, headers)
        RestClient::Response.new(response.body.join, response)
      end
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
        out[key.downcase] = [value]
        out
      }
    end    
  end
  
  RACK_APP = Proc.new { |env|
    begin
      # get the original request and execute it
      response = env['restclient.request'].original_execute
      # to satisfy Rack::Lint
      response.headers.delete(:status)
      [response.code, RestClient.debeautify_headers( response.headers ), [response.to_s]]
    rescue RestClient::NotModified => e
       # e is a Net::HTTPResponse
      response = RestClient::Response.new(e.response.to_s, e.response)
      [304, RestClient.debeautify_headers( response.headers ), [response.to_s]]
    end
  }
end