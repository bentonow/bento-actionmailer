# frozen_string_literal: true

require "ostruct"
require "mail"
require "json"
require_relative "../fixtures/sample_mail"

module Bento
  module TestHelperExtensions
    DEFAULT_SETTINGS = {
      site_uuid: "test-site-uuid",
      publishable_key: "test-publishable-key",
      secret_key: "test-secret-key",
      transactional: true
    }.freeze

    module_function

    def build_delivery_method(settings = {})
      BentoActionMailer::DeliveryMethod.new(DEFAULT_SETTINGS.merge(settings))
    end

    def build_response(status, body: "", message: nil)
      OpenStruct.new(code: status.to_s, body: body, message: message)
    end

    def stub_http_response(status: 202, body: "", message: "Accepted")
      response = build_response(status, body: body, message: message)
      [response, -> { response }]
    end

    def build_mail_message(
      to: "recipient@example.com",
      from: "sender@example.com",
      subject: "Test Subject",
      html_body: "<p>Hello</p>",
      text_body: "Hello"
    )
      mail = Mail.new
      mail.to = Array(to)
      mail.from = Array(from)
      mail.subject = subject

      if text_body
        mail.text_part = Mail::Part.new do
          content_type "text/plain; charset=UTF-8"
          body text_body
        end
      end

      if html_body
        mail.html_part = Mail::Part.new do
          content_type "text/html; charset=UTF-8"
          body html_body
        end
      end

      mail
    end

    def build_text_only_mail(**kwargs)
      build_mail_message(**kwargs.merge(html_body: nil))
    end

    def build_mail_with_custom_parts(to:, from:, subject:, parts: [])
      mail = Mail.new
      mail.to = Array(to)
      mail.from = Array(from)
      mail.subject = subject

      parts.each { |part| mail.add_part(part) }
      mail
    end

    def load_api_responses_fixture
      fixture_path = File.expand_path("../fixtures/api_responses.json", __dir__)
      JSON.parse(File.read(fixture_path))
    end

    def fixture_mail(name)
      MailFixtures.public_send(name)
    end

    def build_mail_stub(to:, from:, subject:, body:)
      Struct.new(:to, :from, :subject, :body).new(Array(to), Array(from), subject, body)
    end

    def with_stubbed_rails(version: nil)
      original_defined = Object.const_defined?(:Rails)
      original_rails = Object.const_get(:Rails) if original_defined
      Object.send(:remove_const, :Rails) if original_defined

      stubbed = Module.new do
        if version
          gem_version = Gem::Version.new(version)
          define_singleton_method(:gem_version) { gem_version }
          define_singleton_method(:version) { version }
        end

        const_set(:Railtie, Class.new) unless const_defined?(:Railtie)
      end

      Object.const_set(:Rails, stubbed)
      yield
    ensure
      Object.send(:remove_const, :Rails) if Object.const_defined?(:Rails)
      Object.const_set(:Rails, original_rails) if original_defined
    end

    def without_rails
      original_defined = Object.const_defined?(:Rails)
      original_rails = Object.const_get(:Rails) if original_defined
      Object.send(:remove_const, :Rails) if original_defined

      yield
    ensure
      Object.const_set(:Rails, original_rails) if original_defined
    end

    def reset_premailer_inliner(delivery_method)
      ivar = :@premailer_inliner
      delivery_method.remove_instance_variable(ivar) if delivery_method.instance_variable_defined?(ivar)
    end
  end
end
