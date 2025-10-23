# frozen_string_literal: true

module BentoActionMailer
  class DeliveryPipelineFactory
    ACTION_CLASSES = [
      Actions::EnsureMail,
      Actions::ExtractAddresses,
      Actions::ExtractSubject,
      Actions::ExtractBodies,
      Actions::DispatchEmail
    ].freeze

    def initialize(delivery_method)
      @delivery_method = delivery_method
    end

    def build
      Pipeline.new(ACTION_CLASSES.map { |klass| klass.new(delivery_method) })
    end

    private

    attr_reader :delivery_method
  end
end
