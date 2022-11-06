require "bento_actionmailer/version"
require "bento_actionmailer/railtie" if defined? Rails

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
      send_mail(
        to: mail.to,
        from: mail.from,
        subject: mail.subject,
        html_body: mail.body.raw_source,
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

      # TODO: remove when confirmed that email delivery works
      puts response.body
    end
  end
end
