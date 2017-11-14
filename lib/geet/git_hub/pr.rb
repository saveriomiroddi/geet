# frozen_string_literal: true

module Geet
  module GitHub
    class PR < AbstractIssue
      # See AbstractIssue for the circular dependency issue notes.
      autoload :AbstractIssue, File.expand_path('abstract_issue', __dir__)

      # See https://developer.github.com/v3/pulls/#create-a-pull-request
      #
      def self.create(title, description, head, api_helper)
        request_address = "#{api_helper.api_repo_link}/pulls"

        if api_helper.upstream?
          account = Geet::GitHub::Account.new(api_helper)
          head = "#{account.authenticated_user}:#{head}"
        end

        request_data = { title: title, body: description, head: head, base: 'master' }

        response = api_helper.send_request(request_address, data: request_data)

        number, title, link = response.fetch_values('number', 'title', 'html_url')

        new(number, api_helper, title, link)
      end

      # See https://developer.github.com/v3/pulls/#list-pull-requests
      #
      def self.list(api_helper, head: nil)
        request_address = "#{api_helper.api_repo_link}/pulls"
        request_params = { head: head } if head

        response = api_helper.send_request(request_address, params: request_params, multipage: true)

        response.map do |issue_data|
          number = issue_data.fetch('number')
          title = issue_data.fetch('title')
          link = issue_data.fetch('html_url')

          new(number, api_helper, title, link)
        end
      end

      # See https://developer.github.com/v3/pulls/#merge-a-pull-request-merge-button
      #
      def merge
        request_address = "#{@api_helper.api_repo_link}/pulls/#{number}/merge"

        @api_helper.send_request(request_address, http_method: :put)
      end

      def request_review(reviewers)
        request_data = { reviewers: reviewers }
        request_address = "#{@api_helper.api_repo_link}/pulls/#{number}/requested_reviewers"

        @api_helper.send_request(request_address, data: request_data)
      end
    end
  end
end
