# frozen_string_literal: true

module BentoActionMailer
  module Actions
    class ExtractBodies
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      def call(context, next_action)
        message = context.fetch(:message)
        context[:html_body] = delivery_method.send(:extract_html_body, message)
        context[:text_body] = delivery_method.send(:extract_text_body, message)
        next_action.call(context)
      end

      private

      attr_reader :delivery_method
    end
  end
end
