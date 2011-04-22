require "typhoeus"

class Capybara::Driver::Typhoeus < Capybara::Driver::Base
  class Node < Capybara::Driver::RackTest::Node
    def click
      driver.process(:get, self[:href].to_s) if self[:href] && self[:href] != ""
    end
  end

  attr_accessor :as, :follow
  attr_reader :app, :rack_server, :options, :response

  def client
    @client ||= Typhoeus::Hydra.new
  end
  
  def initialize(app, options={})
    @app = app
    @options = options
    @rack_server = Capybara::Server.new(@app)
    @rack_server.boot if Capybara.run_server
  end

  def visit(url, params = {})
    reset_cache
    process :get, url, params
  end
  
  def get(url, params = {}, headers = {})
    reset_cache
    process :get, url, params, headers
  end

  def post(url, params = {}, headers = {})
    reset_cache
    process :post, url, params, headers
  end

  def put(url, params = {}, headers = {})
    reset_cache
    process :put, url, params, headers
  end

  def delete(url, params = {}, headers = {})
    reset_cache
    process :delete, url, params, headers
  end

  def head(url, params = {}, headers = {})
    reset_cache
    process :head, url, params, headers
  end

  def patch(url, params = {}, headers = {})
    reset_cache
    process :patch, url, params, headers
  end

  def request(url, params = {}, headers = {})
    reset_cache
    process :request, url, params, headers
  end
  
  def submit(method, path, attributes)
    path = request.path if not path or path.empty?
    process method.to_sym, path, attributes
  end

  def find(selector)
    content_type = response_headers["Content-Type"]
    case content_type.to_s[/\A[^;]+/]
    when "application/xml", "text/xml"
      xml
    when "text/html"
      html
    else
      # $stdout.puts "response: #{response.inspect}"
      raise "Content-Type: #{content_type} is not handling xpath search"
    end.xpath(selector).map { |node| Node.new(self, node) }
  end
  
  def html
    @html ||= Nokogiri::HTML body
  end
  
  def xml
    @xml ||= Nokogiri::XML body
  end
  
  def json
    @json ||= ActiveSupport::JSON.decode body
  end
  
  def body
    # $stdout.puts "body: #{response.body}"
    response.body
  end
  alias_method :source, :body
  
  def response_headers
    response.headers_hash
  end

  def status_code
    response.code
  end
  
  def current_url
    @current_uri.to_s
  end
  
  def reset!
    @client = nil
    @response = nil
    @current_uri = nil
    reset_cache
  end
  
  def as
    @as ||= "application/json"
  end
  
  def with
    @with ||= {}
  end

  def process(method, path, params = {}, headers = {})
    @current_uri = url path
    opts = {
      :method => method,
      :headers => headers.merge("Content-Type" => as, "Accept" => as),
      :timeout => 100,
    }
    opts[method==:get ? :params : :body] = params
    # $stdout.puts "current_uri: #{@current_uri}"
    # $stdout.puts "opts: #{opts.inspect}"
    request = Typhoeus::Request.new @current_uri, opts
    client.queue request
    client.run
    @response = request.response
  end

  def url(path)
    rack_server.url(path)
  end

private

  def reset_cache
    @xml = nil
    @html = nil
    @json = nil
  end

end