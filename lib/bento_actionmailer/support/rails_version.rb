# frozen_string_literal: true

module BentoActionMailer
  module Support
    module RailsVersion
      MINIMUM_PREMAILER_VERSION = Gem::Version.new("7.0").freeze

      module_function

      def current
        return unless defined?(::Rails)

        version = fetch_version
        Gem::Version.new(version) if version
      rescue ArgumentError
        nil
      end

      def rails_7_or_higher?
        version = current
        version && version >= MINIMUM_PREMAILER_VERSION
      end

      def fetch_version
        return ::Rails.gem_version.to_s if ::Rails.respond_to?(:gem_version)
        return ::Rails.version.to_s if ::Rails.respond_to?(:version)

        nil
      end
      private_class_method :fetch_version
    end
  end
end
