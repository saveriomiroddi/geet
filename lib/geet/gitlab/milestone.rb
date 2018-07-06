# frozen_string_literal: true

require 'date'

module Geet
  module Gitlab
    class Milestone
      attr_reader :number, :title, :due_on

      def initialize(number, title, due_on, api_interface)
        @number = number
        @title = title
        @due_on = due_on

        @api_interface = api_interface
      end

      # Endpoint: https://docs.gitlab.com/ee/api/milestones.html#list-project-milestones
      #
      def self.list(api_interface)
        api_path = "milestones"

        response = api_interface.send_request(api_path, multipage: true)

        response.map do |milestone_data|
          number = milestone_data.fetch('iid')
          title = milestone_data.fetch('title')
          due_on = parse_due_date(milestone_data.fetch('due_date'))

          new(number, title, due_on, api_interface)
        end
      end

      class << self
        private

        def parse_due_date(raw_due_date)
          Date.parse(raw_due_date) if raw_due_date
        end
      end
    end # Milestone
  end # Gitlab
end # Geet
