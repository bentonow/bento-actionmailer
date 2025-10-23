# frozen_string_literal: true

require "bento_actionmailer/version"
require "bento_actionmailer/railtie" if defined? Rails
require "bento_actionmailer/support/rails_version"
require "bento_actionmailer/pipeline"
require "bento_actionmailer/actions"
require "bento_actionmailer/premailer_inliner"
require "bento_actionmailer/message_extractor"
require "bento_actionmailer/delivery_pipeline_factory"
require "bento_actionmailer/premailer_support"

require "net/http"
require "uri"
require "json"
require "openssl"
require "cgi"

module BentoActionMailer
  class DeliveryMethod
    include PremailerSupport
    class DeliveryError < StandardError
      attr_reader :response_code, :error_details

      def initialize(message, response_code: nil, error_details: nil)
        super(message)
        @response_code = response_code
        @error_details = error_details
      end
    end

    BENTO_ENDPOINT = URI.parse("https://app.bentonow.com/api/v1/batch/emails")

    DEFAULTS = {
      transactional: true
    }.freeze

    UNAUTHORIZED_AUTHOR_ERROR = "Author not authorized to send on this account"
    UNKNOWN_RESPONSE_MESSAGE = "Unknown response"

    attr_accessor :settings

    def initialize(params = {})
      self.settings = DEFAULTS.merge(normalize_settings(params))
    end

    def deliver!(mail)
      context = {
        mail: mail,
        personalization: {}
      }

      pipeline = DeliveryPipelineFactory.new(self).build
      pipeline.call(context)[:result]
    end

    private

    def normalize_settings(params)
      return {} if params.nil?
      raise TypeError, "Settings must be provided as a hash-like object" unless params.respond_to?(:to_hash)

      params.to_hash
    end

    def ensure_mail!(mail)
      raise DeliveryError, "Mail message is required" unless mail&.respond_to?(:body)

      mail
    end

    def extract_html_body(mail)
      extractor = MessageExtractor.new(mail)
      html_body = extractor.html_body
      return inline_html(html_body) if html_body

      text_body = extractor.text_body
      if text_body
        generated_html = build_html_from_text(text_body)
        return inline_html(generated_html)
      end

      raise DeliveryError, "No HTML body given. Bento requires an html email body."
    end

    def extract_text_body(mail)
      MessageExtractor.new(mail).text_body
    end

    def extract_address(addresses, field_name)
      value = Array(addresses).compact.map { |address| address.to_s.strip }.find { |address| !address.empty? }
      raise DeliveryError, "Mail #{field_name} address is required" unless value

      value
    end

    def extract_subject(subject)
      value = subject.to_s.strip
      raise DeliveryError, "Mail subject is required" if value.empty?

      subject.to_s
    end

    def require_setting(key)
      value = settings[key] || settings[key.to_s]
      value = value.to_s.strip if value
      raise DeliveryError, "Delivery setting #{key} is required" if value.nil? || value.empty?

      value
    end

    def delivery_actions
      [
        Actions::EnsureMail.new(self),
        Actions::ExtractAddresses.new(self),
        Actions::ExtractSubject.new(self),
        Actions::ExtractBodies.new(self),
        Actions::DispatchEmail.new(self)
      ]
    end

    def send_mail(mail_payload, personalization: {})
      site_uuid = require_setting(:site_uuid)
      publishable_key = require_setting(:publishable_key)
      secret_key = require_setting(:secret_key)

      to = mail_payload.fetch(:to)
      from = mail_payload.fetch(:from)
      subject = mail_payload.fetch(:subject)
      html_body = mail_payload.fetch(:html_body)
      text_body = mail_payload[:text_body]

      import_data = [
        {
          to: to,
          from: from,
          subject: subject,
          html_body: html_body,
          text_body: text_body,
          transactional: settings[:transactional],
          personalizations: personalization
        }
      ]

      request = Net::HTTP::Post.new(BENTO_ENDPOINT)
      request.basic_auth(publishable_key, secret_key)
      request.body = JSON.dump({ site_uuid: site_uuid, emails: import_data })
      request.content_type = "application/json"
      req_options = { use_ssl: BENTO_ENDPOINT.scheme == "https" }

      response = Net::HTTP.start(BENTO_ENDPOINT.hostname, BENTO_ENDPOINT.port, req_options) do |http|
        http.request(request)
      end

      handle_response(response)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError => error
      raise build_delivery_error("Network error: #{error.message}", nil, { "exception" => error.class.name })
    end

    def handle_response(response)
      status = response.code.to_i
      return if success_response?(status)

      error_data = parse_error_response(response)
      error_message = error_data&.dig("error") || response.message || UNKNOWN_RESPONSE_MESSAGE

      case status
      when 401, 403
        raise_authorization_error(status, error_data, error_message)
      when 400..499
        raise build_delivery_error("Client error: #{error_message}", status, error_data)
      when 500..599
        raise build_delivery_error("Bento API server error: #{error_message}", status, error_data)
      else
        raise build_delivery_error("Unexpected response: #{status} #{error_message}", status, error_data)
      end
    end

    def parse_error_response(response)
      body = response.body
      return nil if body.nil?

      body = body.strip
      return nil if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def raise_authorization_error(status, error_data, error_message)
      if error_message == UNAUTHORIZED_AUTHOR_ERROR
        raise build_delivery_error(UNAUTHORIZED_AUTHOR_ERROR, status, error_data)
      end

      sanitized_message = error_message
      sanitized_message = nil if sanitized_message == UNKNOWN_RESPONSE_MESSAGE
      sanitized_message = sanitized_message&.strip
      message = sanitized_message && !sanitized_message.empty? ? "Authorization failed: #{sanitized_message}" : "Authorization failed"
      raise build_delivery_error(message, status, error_data)
    end

    def success_response?(status)
      status.between?(200, 299)
    end

    def build_delivery_error(message, status, error_data)
      DeliveryError.new(message, response_code: status, error_details: error_data)
    end

    def build_html_from_text(text_body)
      sanitized = CGI.escapeHTML(text_body.to_s)
      paragraphs = sanitized.split(/\n{2,}/).map do |block|
        "<p>#{block.gsub("\n", "<br>")}</p>"
      end

      body = paragraphs.empty? ? "<p>#{sanitized.gsub("\n", "<br>")}</p>" : paragraphs.join
      "<div class=\"bento-text-only\">#{body}</div>"
    end

    def inline_html(html)
      return html unless rails_7_or_higher?

      premailer_inliner.inline(html)
    end
  end
end
