# frozen_string_literal: true

module BentoActionMailer
  module PremailerSupport
    def rails_7_or_higher?
      Support::RailsVersion.rails_7_or_higher?
    end

    def ensure_premailer_loaded!
      return unless rails_7_or_higher?
      return if defined?(::Premailer)

      require "premailer/rails"
    rescue LoadError => error
      raise build_delivery_error(
        "premailer-rails (~> 1.11) is required when using Rails 7.0 or higher. " \
        "Add `gem \"premailer-rails\", \"~> 1.11\"` to your application.",
        nil,
        { "dependency" => "premailer-rails", "original_error" => error.message }
      )
    end

    def premailer_inliner
      @premailer_inliner ||= PremailerInliner.new(
        loader: method(:ensure_premailer_loaded!),
        logger: rails_logger
      )
    end

    def rails_logger
      return unless defined?(::Rails)

      Rails.respond_to?(:logger) ? Rails.logger : nil
    end
  end
end
