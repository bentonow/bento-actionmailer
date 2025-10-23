# frozen_string_literal: true

require "bento_actionmailer/version"
require "bento_actionmailer/railtie" if defined? Rails

require "net/http"
require "uri"
require "json"
require "openssl"

module BentoActionMailer
  class DeliveryMethod
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
      message = ensure_mail!(mail)
      html_body = extract_html_body(message)

      send_mail(
        to: extract_address(message.to, :to),
        from: extract_address(message.from, :from),
        subject: extract_subject(message.subject),
        html_body: html_body,
        personalization: {}
      )
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
      html_part = Array(mail.body&.parts).find { |part| part.content_type =~ %r{text/html} }
      raise DeliveryError, "No HTML body given. Bento requires an html email body." unless html_part

      html_part.decoded
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

    def send_mail(to:, from:, subject:, html_body:, personalization: {})
      site_uuid = require_setting(:site_uuid)
      publishable_key = require_setting(:publishable_key)
      secret_key = require_setting(:secret_key)

      import_data = [
        {
          to: to,
          from: from,
          subject: subject,
          html_body: html_body,
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
  end
end
