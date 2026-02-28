# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'yaml'
require 'openssl'

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Opn
    # HTTP client for communicating with the OPNsense REST API.
    # Credentials and connection details are read from YAML config files
    # managed by the opn Puppet class (manifests/init.pp).
    class ApiClient
      DEFAULT_URL = 'http://localhost:80/api'
      MAX_REDIRECTS = 5

      # Path to the provider config file written by the opn Puppet class.
      # Uses Puppet[:confdir] so it is automatically correct on every OS:
      #   Linux   -> /etc/puppetlabs/puppet/opn_provider.yaml
      #   FreeBSD -> /usr/local/etc/puppet/opn_provider.yaml
      # This value equals ${settings::confdir} in Puppet manifests.
      def self.provider_config_path
        File.join(Puppet[:confdir], 'opn_provider.yaml')
      end

      # Returns the directory that holds per-device credential files.
      # Reads config_dir from the provider config file written by init.pp.
      # Falls back to <puppet_confdir>/opn if the file does not exist yet.
      def self.config_base_dir
        path = provider_config_path
        if File.exist?(path)
          config = YAML.safe_load_file(path)
          (config.is_a?(Hash) && config['config_dir']) ? config['config_dir'] : default_config_dir
        else
          default_config_dir
        end
      end

      def self.default_config_dir
        File.join(Puppet[:confdir], 'opn')
      end

      # @param url [String] Base URL of the OPNsense API
      # @param api_key [String] OPNsense API key
      # @param api_secret [String] OPNsense API secret
      # @param ssl_verify [Boolean] Whether to verify SSL certificates
      # @param timeout [Integer] HTTP timeout in seconds
      def initialize(url:, api_key:, api_secret:, ssl_verify: true, timeout: 60)
        @url = url.to_s.chomp('/')
        @api_key = api_key
        @api_secret = api_secret
        @ssl_verify = ssl_verify
        @timeout = timeout.to_i
      end

      # Creates an ApiClient instance from a device's YAML config file.
      #
      # @param device_name [String] Device name (filename without .yaml extension)
      # @return [PuppetX::Opn::ApiClient]
      # @raise [Puppet::Error] if config file is missing or malformed
      def self.from_device(device_name)
        config_path = config_path_for(device_name)
        unless File.exist?(config_path)
          raise Puppet::Error,
                "OPNsense config file not found for device '#{device_name}': #{config_path}. " \
                'Ensure the opn class is applied before using opn_* resources.'
        end

        config = YAML.safe_load_file(config_path)
        unless config.is_a?(Hash)
          raise Puppet::Error, "OPNsense config file '#{config_path}' is not a valid YAML hash."
        end

        new(
          url:        config['url'] || DEFAULT_URL,
          api_key:    config['api_key'].to_s,
          api_secret: config['api_secret'].to_s,
          ssl_verify: config.fetch('ssl_verify', true),
          timeout:    config.fetch('timeout', 60),
        )
      end

      # Returns all device names found in the config directory.
      # Each YAML file in config_base_dir corresponds to one OPNsense device.
      #
      # @return [Array<String>] List of device names
      def self.device_names
        Dir.glob(File.join(config_base_dir, '*.yaml')).map do |f|
          File.basename(f, '.yaml')
        end
      end

      # Returns the expected config file path for a given device name.
      #
      # @param device_name [String]
      # @return [String]
      def self.config_path_for(device_name)
        File.join(config_base_dir, "#{device_name}.yaml")
      end

      # Performs an HTTP GET request to the OPNsense API.
      #
      # @param path [String] API path (relative, e.g. 'firewall/alias/search_item')
      # @return [Hash] Parsed JSON response
      def get(path)
        uri = build_uri(path)
        http_request(:get, uri)
      end

      # Performs an HTTP POST request to the OPNsense API.
      #
      # @param path [String] API path (relative)
      # @param data [Hash] Request body (serialised as JSON)
      # @return [Hash] Parsed JSON response
      def post(path, data = {})
        uri = build_uri(path)
        http_request(:post, uri, data)
      end

      private

      # Executes an HTTP request, following redirects transparently.
      # Supports 301, 302 (redirect with GET), 307, 308 (redirect preserving method).
      # OPNsense commonly issues 308 redirects when HTTP is used but HTTPS is required.
      #
      # @param method [Symbol] :get or :post
      # @param uri [URI] Fully qualified URI
      # @param data [Hash, nil] POST body data
      # @param redirect_count [Integer] Internal redirect counter
      # @return [Hash] Parsed JSON response
      def http_request(method, uri, data = nil, redirect_count = 0)
        if redirect_count > MAX_REDIRECTS
          raise Puppet::Error, "OPNsense API: too many redirects (> #{MAX_REDIRECTS}) for '#{uri}'"
        end

        http = build_http(uri)
        request = build_request(method, uri, data)
        request.basic_auth(@api_key, @api_secret)
        request['Accept'] = 'application/json'
        request['Content-Type'] = 'application/json' if method == :post

        response = http.request(request)
        code = response.code.to_i

        if [301, 302, 307, 308].include?(code)
          location = response['location']
          unless location
            raise Puppet::Error,
                  "OPNsense API #{code} redirect with no Location header for '#{uri}'"
          end

          Puppet.debug("opn: following #{code} redirect to '#{location}'")
          new_uri = URI.parse(location)

          # 307/308 preserve the original method and body.
          # 301/302 conventionally switch to GET.
          return http_request(method, new_uri, data, redirect_count + 1) if [307, 308].include?(code)

          return http_request(:get, new_uri, nil, redirect_count + 1)
        end

        handle_response(response, uri.to_s)
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        raise Puppet::Error, "OPNsense API connection failed for '#{uri}': #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise Puppet::Error, "OPNsense API timeout for '#{uri}': #{e.message}"
      end

      def build_uri(path)
        clean_path = path.to_s.sub(%r{^/+}, '')
        URI.parse("#{@url}/#{clean_path}")
      rescue URI::InvalidURIError => e
        raise Puppet::Error, "Invalid OPNsense API path '#{path}': #{e.message}"
      end

      def build_http(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = @ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        end

        http
      end

      def build_request(method, uri, data)
        case method
        when :get
          Net::HTTP::Get.new(uri)
        when :post
          req = Net::HTTP::Post.new(uri)
          req.body = data.to_json
          req
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end
      end

      def handle_response(response, request_uri)
        code = response.code.to_i
        unless (200..299).cover?(code)
          raise Puppet::Error, "OPNsense API error #{code} for '#{request_uri}': #{response.body}"
        end

        body = response.body
        return {} if body.nil? || body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError => e
        raise Puppet::Error, "OPNsense API response parse error for '#{request_uri}': #{e.message}"
      end
    end
  end
end
