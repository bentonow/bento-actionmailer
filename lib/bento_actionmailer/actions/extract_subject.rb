# frozen_string_literal: true

module BentoActionMailer
  module Actions
    class ExtractSubject
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      def call(context, next_action)
        message = context.fetch(:message)
        context[:subject] = delivery_method.send(:extract_subject, message.subject)
        next_action.call(context)
      end

      private

      attr_reader :delivery_method
    end
  end
end
