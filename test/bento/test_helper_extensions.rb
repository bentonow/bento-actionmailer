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
  end
end
