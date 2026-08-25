# frozen_string_literal: true

require "bento_actionmailer/version"
require "bento_actionmailer/railtie" if defined? Rails

require "json"
require "net/http"
require "uri"

module BentoActionMailer
  def self.deliver_batch!(mails, settings = nil)
    raise ArgumentError, "deliver_batch! expects an array of mails" unless mails.is_a?(Array)

    resolved_settings =
      if !settings.nil?
        settings
      elsif defined?(ActionMailer::Base) && ActionMailer::Base.respond_to?(:bento_actionmailer_settings)
        ActionMailer::Base.bento_actionmailer_settings
      else
        {}
      end

    DeliveryMethod.new(resolved_settings).deliver_batch!(mails)
  end

  # Action Mailer delivery method that sends emails through Bento's batch email API.
  class DeliveryMethod
    class DeliveryError < StandardError; end

    BENTO_ENDPOINT = URI.parse("https://app.bentonow.com/api/v1/batch/emails")
    BATCH_LIMIT = 60

    DEFAULTS = {
      transactional: true
    }.freeze

    attr_accessor :settings

    def initialize(params = {})
      self.settings = DEFAULTS.merge(params)
    end

    def deliver!(mail)
      post_emails([email_payload_from_mail(mail)])
    end

    def deliver_batch!(mails)
      raise ArgumentError, "deliver_batch! expects an array of mails" unless mails.is_a?(Array)
      return if mails.empty?

      mails.each_slice(BATCH_LIMIT) do |slice|
        post_emails(slice.map { |item| email_payload_from_mail(message_from(item)) })
      end
    end

    private

    def send_mail(to:, from:, subject:, html_body:, reply_to: nil, personalization: {})
      post_emails([email_payload(to, from, subject, html_body, personalization, reply_to: reply_to)])
    end

    def post_emails(payloads)
      request = Net::HTTP::Post.new(BENTO_ENDPOINT)
      request.basic_auth(settings[:publishable_key], settings[:secret_key])
      request.body = JSON.dump(
        site_uuid: settings[:site_uuid],
        emails: payloads
      )
      request.content_type = "application/json"
      handle_response(perform_request(request))
    end

    def perform_request(request)
      req_options = { use_ssl: BENTO_ENDPOINT.scheme == "https" }

      Net::HTTP.start(BENTO_ENDPOINT.hostname, BENTO_ENDPOINT.port, req_options) do |http|
        http.request(request)
      end
    end

    def message_from(item)
      if item.respond_to?(:message) && item.respond_to?(:mailer_class)
        item.message
      else
        item
      end
    end

    def email_payload_from_mail(mail)
      email_payload(
        mail.to.first,
        mail.from.first,
        mail.subject,
        html_body_from(mail),
        {},
        reply_to: mail.reply_to&.first
      )
    end

    def html_body_from(mail)
      html_part = mail.html_part
      if html_part.nil? && mail.body.respond_to?(:parts)
        html_part = mail.body.parts.find { |part| part.content_type =~ %r{text/html} }
      end
      return html_part.decoded if html_part
      return mail.body.decoded if mail.content_type&.include?("text/html")

      raise DeliveryError, "No HTML body given. Bento requires an html email body."
    end

    def email_payload(to, from, subject, html_body, personalization, reply_to: nil)
      payload = {
        to: to,
        from: from,
        subject: subject,
        html_body: html_body,
        transactional: settings[:transactional],
        personalizations: personalization
      }
      payload[:reply_to] = reply_to if reply_to
      payload
    end

    def handle_response(response)
      return response if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, ResponseErrorMessage.new(response).to_s
    end
  end

  # Builds a safe, user-facing exception message from Bento API responses.
  class ResponseErrorMessage
    def initialize(response)
      @response = response
    end

    def to_s
      status = [response.code, response.message].compact.join(" ")
      message = "Bento API request failed"
      message += " (#{status})" unless status.empty?

      api_message = parse_api_error_message(response.body)
      message += ": #{api_message}" if api_message

      message
    end

    private

    def parse_api_error_message(body)
      return if body.nil? || body.empty?

      parsed_body = JSON.parse(body)
      json_error_message(parsed_body)
    rescue JSON::ParserError
      body
    end

    def json_error_message(value)
      case value
      when Hash
        simple_message(value["message"] || value["error"]) || errors_message(value["errors"])
      when Array
        errors_message(value)
      end
    end

    def simple_message(message)
      return if message.nil?

      joined_message = Array(message).compact.join(", ")
      joined_message unless joined_message.empty?
    end

    def errors_message(errors)
      case errors
      when String
        errors
      when Array
        join_messages(errors.map { |error| error_message(error) })
      when Hash
        join_messages(errors.map { |field, messages| field_error_message(field, messages) })
      end
    end

    def error_message(error)
      case error
      when String
        error
      when Hash
        field_error_message(error["field"], error["message"] || error["detail"] || error["title"])
      end
    end

    def field_error_message(field, message)
      return if message.nil? || message.empty?

      return message unless field && !field.empty?

      "#{field}: #{Array(message).join(", ")}"
    end

    def join_messages(messages)
      joined_messages = messages.compact.reject(&:empty?).join(", ")
      joined_messages unless joined_messages.empty?
    end

    attr_reader :response
  end
end
