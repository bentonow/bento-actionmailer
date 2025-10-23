# frozen_string_literal: true

module BentoActionMailer
  class PremailerInliner
    OPTIONS = {
      with_html_string: true,
      adapter: :nokogiri,
      remove_ids: false,
      css_to_attributes: true,
      preserve_styles: true
    }.freeze

    def initialize(loader:, logger:)
      @loader = loader
      @logger = logger
    end

    def inline(html)
      loader.call
      premailer(html).to_inline_css
    rescue StandardError => error
      logger&.warn("[BentoActionMailer] Premailer processing failed: #{error.message}")
      html
    end

    private

    attr_reader :loader, :logger

    def premailer(html)
      options = OPTIONS.dup
      if defined?(::Premailer::Warnings)
        options[:warn_level] = ::Premailer::Warnings::SAFE
      end

      Premailer.new(html, options)
    end
  end
end
