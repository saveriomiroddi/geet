# frozen_string_literal: true

module Geet
  module Gitlab
    class Issue
      attr_reader :number, :title, :link

      def initialize(number, title, link)
        @number = number
        @title = title
        @link = link
      end

      # Endpoint: https://docs.gitlab.com/ee/api/issues.html#list-issues
      #
      def self.list(api_interface, assignee: nil, milestone: nil)
        api_path = "issues"

        request_params = {}
        request_params[:assignee_id] = assignee.id if assignee
        request_params[:milestone] = milestone.title if milestone

        response = api_interface.send_request(api_path, params: request_params, multipage: true)

        response.map do |issue_data, result|
          number = issue_data.fetch('iid')
          title = issue_data.fetch('title')
          link = issue_data.fetch('web_url')

          new(number, title, link)
        end
      end
    end
  end
end
