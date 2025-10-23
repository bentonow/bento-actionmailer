# frozen_string_literal: true

require "mail"

module MailFixtures
  module_function

  DEFAULT_TO = "recipient@example.com"
  DEFAULT_FROM = "sender@example.com"
  DEFAULT_SUBJECT = "Fixture Subject"

  def multipart_html_mail(to: DEFAULT_TO, from: DEFAULT_FROM, subject: DEFAULT_SUBJECT)
    build_message(to: to, from: from, subject: subject) do |mail|
      mail.text_part = Mail::Part.new do
        content_type "text/plain; charset=UTF-8"
        body "Plain text content"
      end

      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body "<p>HTML content</p>"
      end
    end
  end

  def html_only_mail(to: DEFAULT_TO, from: DEFAULT_FROM, subject: DEFAULT_SUBJECT)
    build_message(to: to, from: from, subject: subject) do |mail|
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body "<p>HTML only</p>"
      end
    end
  end

  def text_only_mail(to: DEFAULT_TO, from: DEFAULT_FROM, subject: DEFAULT_SUBJECT)
    build_message(to: to, from: from, subject: subject) do |mail|
      mail.text_part = Mail::Part.new do
        content_type "text/plain; charset=UTF-8"
        body "Plain text only"
      end
    end
  end

  def special_character_mail
    multipart_html_mail(
      to: "büyer+test@example.com",
      from: "✨ sender@example.com",
      subject: "Unicode ✓"
    )
  end

  def large_html_mail(size: 50_000)
    html = "<div>#{"A" * size}</div>"
    html_only_mail(subject: "Large HTML", to: DEFAULT_TO, from: DEFAULT_FROM).tap do |mail|
      mail.html_part.body = html
    end
  end

  def malformed_mail
    Struct.new(:to, :from, :subject, :body).new([DEFAULT_TO], [DEFAULT_FROM], DEFAULT_SUBJECT, nil)
  end

  def nested_html_mail
    html_only_mail(subject: "Nested").tap do |mail|
      mail.html_part.body = "<section><article><p>Nested content</p></article></section>"
    end
  end

  def html_with_script_mail
    html_only_mail(subject: "Contains Script").tap do |mail|
      mail.html_part.body = "<html><body><script>alert('test')</script><p>Content</p></body></html>"
    end
  end

  def build_message(to:, from:, subject:)
    mail = Mail.new
    mail.to = Array(to)
    mail.from = Array(from)
    mail.subject = subject
    yield(mail)
    mail
  end
end
