# frozen_string_literal: true

module BentoActionMailer
  module Actions
    class ExtractAddresses
      def initialize(delivery_method)
        @delivery_method = delivery_method
      end

      def call(context, next_action)
        message = context.fetch(:message)
        context[:to] = delivery_method.send(:extract_address, message.to, :to)
        context[:from] = delivery_method.send(:extract_address, message.from, :from)
        next_action.call(context)
      end

      private

      attr_reader :delivery_method
    end
  end
end
