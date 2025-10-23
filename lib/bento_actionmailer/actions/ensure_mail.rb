# frozen_string_literal: true

module BentoActionMailer
  module Actions
    class EnsureMail
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      def call(context, next_action)
        context[:message] = delivery_method.send(:ensure_mail!, context.fetch(:mail))
        next_action.call(context)
      end

      private

      attr_reader :delivery_method
    end
  end
end
