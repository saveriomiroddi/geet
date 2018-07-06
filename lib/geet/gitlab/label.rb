# frozen_string_literal: true

module Geet
  module Gitlab
    class Label
      attr_reader :name, :color

      def initialize(name, color)
        @name = name
        @color = color
      end

      # Endpoint: https://docs.gitlab.com/ee/api/labels.html#list-labels
      #
      # Returns a flat list of names in string form.
      #
      def self.list(api_interface)
        api_path = "labels"
        response = api_interface.send_request(api_path, multipage: true)

        response.map do |label_entry|
          name = label_entry.fetch('name')
          color = label_entry.fetch('color').sub('#', '') # normalize

          new(name, color)
        end
      end

      # Endpoint: https://docs.gitlab.com/ee/api/labels.html#create-a-new-label
      #
      def self.create(name, color, api_interface)
        api_path = "labels"
        request_data = { name: name, color: "##{color}" }

        api_interface.send_request(api_path, data: request_data)

        new(name, color)
      end
    end
  end
end
