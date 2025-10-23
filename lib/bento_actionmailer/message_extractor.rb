# frozen_string_literal: true

module BentoActionMailer
  class MessageExtractor
    HTML_PATTERN = %r{text/html}.freeze
    TEXT_PATTERN = %r{text/plain}.freeze

    def initialize(message)
      @message = message
    end

    def html_body
      extract_body(HTML_PATTERN)
    end

    def text_body
      extract_body(TEXT_PATTERN)
    end

    private

    attr_reader :message

    def extract_body(pattern)
      part = explicit_part(pattern) || fallback_part(pattern)
      part ? decoded(part) : nil
    end

    def explicit_part(pattern)
      if pattern == HTML_PATTERN && message.respond_to?(:html_part)
        message.html_part
      elsif pattern == TEXT_PATTERN && message.respond_to?(:text_part)
        message.text_part
      end
    end

    def fallback_part(pattern)
      return message if content_type_for(message)&.match?(pattern)

      body = message.respond_to?(:body) ? message.body : nil
      return body if body && content_type_for(body)&.match?(pattern)

      nil
    end

    def content_type_for(entity)
      return entity.content_type if entity.respond_to?(:content_type)
      return entity.mime_type if entity.respond_to?(:mime_type)

      nil
    end

    def decoded(entity)
      if entity.respond_to?(:decoded)
        entity.decoded
      elsif entity.respond_to?(:body) && entity.body.respond_to?(:decoded)
        entity.body.decoded
      elsif entity.equal?(message) && message.respond_to?(:body) && message.body.respond_to?(:decoded)
        message.body.decoded
      end
    end
  end
end
