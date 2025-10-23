# frozen_string_literal: true

module BentoActionMailer
  module Actions
    class DispatchEmail
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      def call(context, next_action)
        payload = {
          to: context.fetch(:to),
          from: context.fetch(:from),
          subject: context.fetch(:subject),
          html_body: context.fetch(:html_body),
          text_body: context[:text_body]
        }

        context[:result] = delivery_method.send(
          :send_mail,
          payload,
          personalization: context.fetch(:personalization, {})
        )
        next_action.call(context)
      end

      private

      attr_reader :delivery_method
    end
  end
end
