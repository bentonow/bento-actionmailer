require "bento_actionmailer/version"
require "bento_actionmailer/railtie" if defined? Rails

require "json"
require "net/http"
require "uri"

module BentoActionMailer
  class DeliveryMethod
    class DeliveryError < StandardError; end

    BENTO_ENDPOINT = URI.parse("https://app.bentonow.com/api/v1/batch/emails")

    DEFAULTS = {
      transactional: true
    }.freeze

    attr_accessor :settings

    def initialize(params = {})
      self.settings = DEFAULTS.merge(params)
    end

    def deliver!(mail)
      html_body = mail.body.parts.find { |p| p.content_type =~ /text\/html/ }
      raise DeliveryError, "No HTML body given. Bento requires an html email body." unless html_body

      send_mail(
        to: mail.to.first,
        from: mail.from.first,
        subject: mail.subject,
        html_body: html_body.decoded,
        personalization: {}
      )
    end

    private

    def send_mail(to:, from:, subject:, html_body:, personalization: {})
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
      request.basic_auth(settings[:publishable_key], settings[:secret_key])
      request.body = JSON.dump({ site_uuid: settings[:site_uuid], emails: import_data })
      request.content_type = "application/json"
      req_options = { use_ssl: BENTO_ENDPOINT.scheme == "https" }

      response = Net::HTTP.start(BENTO_ENDPOINT.hostname, BENTO_ENDPOINT.port, req_options) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    def handle_response(response)
      return response if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, api_error_message(response)
    end

    def api_error_message(response)
      status = [response.code, response.message].compact.join(" ")
      message = "Bento API request failed"
      message += " (#{status})" unless status.empty?

      api_message = parse_api_error_message(response.body)
      message += ": #{api_message}" if api_message

      message
    end

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
  end
end
