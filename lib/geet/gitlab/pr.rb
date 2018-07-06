# frozen_string_literal: true

module Geet
  module Gitlab
    class PR
      attr_reader :number, :title, :link

      def initialize(number, api_interface, title, link)
        @number = number
        @api_interface = api_interface
        @title = title
        @link = link
      end

      # Endpoint: https://docs.gitlab.com/ee/api/merge_requests.html#list-merge-requests
      #
      def self.list(api_interface, milestone: nil, assignee: nil, head: nil)
        api_path = "merge_requests"

        request_params = {}
        request_params[:assignee_id] = assignee.id if assignee
        request_params[:milestone] = milestone.title if milestone
        request_params[:source_branch] = head if head

        response = api_interface.send_request(api_path, params: request_params, multipage: true)

        response.map do |issue_data, result|
          number = issue_data.fetch('iid')
          title = issue_data.fetch('title')
          link = issue_data.fetch('web_url')

          new(number, api_interface, title, link)
        end
      end

      # Endpoint: https://docs.gitlab.com/ee/api/merge_requests.html#accept-mr
      #
      def merge
        api_path = "merge_requests/#{number}/merge"

        @api_interface.send_request(api_path, http_method: :put)
      end
    end # PR
  end # Gitlab
end # Geet
