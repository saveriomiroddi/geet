# frozen_string_literal: true

require 'cgi'
require 'uri'
require 'net/http'
require 'json'

module Geet
  module Gitlab
    class ApiInterface
      API_ROOT_ENDPOINT = 'https://gitlab.com/api/v4'

      # repo_path: "path/namespace"; required for the current GitLab operations.
      # upstream:  boolean; required for the current GitLab operations.
      #
      def initialize(api_token, repo_path:, upstream:)
        @api_token = api_token
        @path_with_namespace = repo_path
        @upstream = upstream
      end

      def upstream?
        @upstream
      end

      def path_with_namespace(encoded: false)
        encoded ? CGI.escape(@path_with_namespace) : @path_with_namespace
      end

      # Send a request.
      #
      # Returns the parsed response, or an Array, in case of multipage.
      # Where no body is present in the response, nil is returned.
      #
      # params:
      #   :api_path:    api path, will be appended to the API URL.
      #                 for root path, prepend a `/`:
      #                 - use `/gists` for `https://api.github.com/gists`
      #                 when owner/project/repos is included, don't prepend `/`:
      #                 - use `issues` for `https://api.github.com/myowner/myproject/repos/issues`
      #   :params:      (Hash)
      #   :data:        (Hash) if present, will generate a POST request, otherwise, a GET
      #   :multipage:   set true for paged Github responses (eg. issues); it will make the method
      #                 return an array, with the concatenated (parsed) responses
      #   :http_method: symbol format of the method (:get, :patch, :post, :put and :delete)
      #                 :get and :post are automatically inferred by the present of :data; the other
      #                 cases must be specified.
      #
      def send_request(api_path, params: nil, data: nil, multipage: false, http_method: nil)
        address = api_url(api_path)
        # filled only on :multipage
        parsed_responses = []

        loop do
          response = send_http_request(address, params: params, data: data, http_method: http_method)

          parsed_response = JSON.parse(response.body) if response.body

          if error?(response)
            formatted_error = decode_and_format_error(parsed_response)
            raise(formatted_error)
          end

          return parsed_response if !multipage

          parsed_responses.concat(parsed_response)

          address = link_next_page(response.to_hash)

          return parsed_responses if address.nil?

          # Gitlab's next link address already includes all the params, so we remove
          # the passed ones (if there's any).
          params = nil
        end
      end

      private

      def api_url(api_path)
        "#{API_ROOT_ENDPOINT}/#{api_path}"
      end

      def send_http_request(address, params: nil, data: nil, http_method: nil)
        uri = encode_uri(address, params)
        http_class = find_http_class(http_method, data)

        Net::HTTP.start(uri.host, use_ssl: true) do |http|
          request = http_class.new(uri)

          request['Private-Token'] = @api_token
          request.body = URI.encode_www_form(data) if data

          http.request(request)
        end
      end

      def encode_uri(address, params)
        address += '?' + URI.encode_www_form(params) if params

        URI(address)
      end

      def error?(response)
        !response.code.start_with?('2')
      end

      def decode_and_format_error(parsed_response)
        if parsed_response.key?('error')
          parsed_response.fetch('error')
        elsif parsed_response.key?('message')
          parsed_response.fetch('message')
        else
          "Unrecognized response: #{parsed_response}"
        end
      end

      def link_next_page(response_headers)
        # An array (or nil) is returned.
        link_header = Array(response_headers['link'])

        return nil if link_header.empty?

        link_header[0][/<(\S+)>; rel="next"/, 1]
      end

      def find_http_class(http_method, data)
        http_method ||= data ? :post : :get

        case http_method
        when :get
          Net::HTTP::Get
        when :delete
          Net::HTTP::Delete
        when :patch
          Net::HTTP::Patch
        when :post
          Net::HTTP::Post
        when :put
          Net::HTTP::Put
        else
          raise "Unsupported HTTP method: #{http_method.inspect}"
        end
      end
    end
  end
end
