# frozen_string_literal: true

module BentoActionMailer
  class Pipeline
    def initialize(actions)
      @actions = Array(actions)
    end

    def call(initial_context)
      sequence = actions.reverse.reduce(->(context) { context }) do |next_action, action|
        ->(context) { action.call(context, next_action) }
      end

      sequence.call(initial_context)
    end

    private

    attr_reader :actions
  end
end
