# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require_relative '../shared/http_error'

module Geet
  module Github
    class ApiInterface
      API_AUTH_USER = '' # We don't need the login, as the API key uniquely identifies the user
      API_ROOT_ENDPOINT = 'https://api.github.com'

      # repo_path: optional for operations that don't require a repository, eg. gist creation.
      # upstream:  boolean; makes sense only when :repo_path is set.
      #
      def initialize(api_token, repo_path: nil, upstream: nil)
        @api_token = api_token
        @repository_path = repo_path
        @upstream = upstream
      end

      def upstream?
        @upstream
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
            error_message = decode_and_format_error(parsed_response)
            raise Geet::Shared::HttpError.new(error_message, response.code)
          end

          return parsed_response if !multipage

          parsed_responses.concat(parsed_response)

          address = link_next_page(response.to_hash)

          return parsed_responses if address.nil?
        end
      end

      private

      def api_url(api_path)
        url = API_ROOT_ENDPOINT

        if !api_path.start_with?('/')
          raise 'Missing repo path!' if @repository_path.nil?
          url += "/repos/#{@repository_path}/"
        end

        url + api_path
      end

      def send_http_request(address, params: nil, data: nil, http_method: nil)
        uri = encode_uri(address, params)
        http_class = find_http_class(http_method, data)

        Net::HTTP.start(uri.host, use_ssl: true) do |http|
          request = http_class.new(uri)

          request.basic_auth API_AUTH_USER, @api_token
          request.body = data.to_json if data
          request['Accept'] = 'application/vnd.github.v3+json'

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
        message = parsed_response['message']

        if parsed_response.key?('errors')
          message += ':'

          error_details = parsed_response['errors'].map do |error_data|
            error_code = error_data.fetch('code')

            if error_code == 'custom'
              " #{error_data.fetch('message')}"
            else
              " #{error_code} (#{error_data.fetch('field')})"
            end
          end

          message += error_details.join(', ')
        end

        message
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
