# frozen_string_literal: true

require "test_helper"

class FakeHttp
  attr_reader :requests

  def initialize(response)
    @response = response
    @requests = []
  end

  def last_request
    @requests.last
  end

  def request(request)
    @requests << request
    @response
  end
end

class BentoActionMailerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::BentoActionMailer::VERSION
  end

  def test_send_mail_returns_success_response
    response = http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")

    with_stubbed_bento_response(response) do |fake_http|
      assert_same response, send_test_mail

      body = JSON.parse(fake_http.last_request.body)
      email = body["emails"].first
      assert_equal "site_test", body["site_uuid"]
      assert_equal "sender@example.com", email["from"]
      refute email.key?("reply_to")
    end
  end

  def test_send_mail_includes_reply_to_when_provided
    response = http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")

    with_stubbed_bento_response(response) do |fake_http|
      send_test_mail(reply_to: "replies@example.com")

      email = JSON.parse(fake_http.last_request.body)["emails"].first
      assert_equal "replies@example.com", email["reply_to"]
    end
  end

  def test_deliver_passes_reply_to_from_mail
    response = http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")

    with_stubbed_bento_response(response) do |fake_http|
      delivery_method.deliver!(html_mail(reply_to: "replies@example.com"))

      email = JSON.parse(fake_http.last_request.body)["emails"].first
      assert_equal "replies@example.com", email["reply_to"]
    end
  end

  def test_deliver_batch_sends_two_multipart_html_mails_in_one_post
    first = html_mail(to: "one@example.com", from: "a@example.com", subject: "First", html: "<p>One</p>")
    second = html_mail(to: "two@example.com", from: "b@example.com", subject: "Second", html: "<p>Two</p>")

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      delivery_method.deliver_batch!([first, second])

      assert_equal 1, fake_http.requests.length
      emails = JSON.parse(fake_http.last_request.body)["emails"]
      assert_equal 2, emails.length
      assert_equal "one@example.com", emails[0]["to"]
      assert_equal "a@example.com", emails[0]["from"]
      assert_equal "First", emails[0]["subject"]
      assert_equal "<p>One</p>", emails[0]["html_body"]
      assert_equal "two@example.com", emails[1]["to"]
      assert_equal "b@example.com", emails[1]["from"]
      assert_equal "Second", emails[1]["subject"]
      assert_equal "<p>Two</p>", emails[1]["html_body"]
    end
  end

  def test_deliver_batch_slices_sixty_one_mails_into_two_posts
    mails = Array.new(61) { |index| html_mail(to: "user#{index}@example.com") }

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      delivery_method.deliver_batch!(mails)

      assert_equal 2, fake_http.requests.length
      first_emails = JSON.parse(fake_http.requests[0].body)["emails"]
      second_emails = JSON.parse(fake_http.requests[1].body)["emails"]
      assert_equal 60, first_emails.length
      assert_equal 1, second_emails.length
      assert_equal fake_http.requests.last, fake_http.last_request
      assert_equal "user60@example.com", second_emails.first["to"]
    end
  end

  def test_deliver_batch_empty_array_does_not_send_http
    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      assert_nil delivery_method.deliver_batch!([])
      assert_nil fake_http.last_request
    end
  end

  def test_deliver_batch_raises_argument_error_for_non_array
    error = assert_raises(ArgumentError) do
      BentoActionMailer.deliver_batch!(html_mail)
    end

    assert_equal "deliver_batch! expects an array of mails", error.message
  end

  def test_deliver_batch_renders_message_delivery_duck_type
    mail = html_mail(to: "duck@example.com", subject: "Duck", html: "<p>Duck</p>")
    delivery = Struct.new(:message, :mailer_class).new(mail, Class.new)

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      delivery_method.deliver_batch!([delivery])

      email = JSON.parse(fake_http.last_request.body)["emails"].first
      assert_equal "duck@example.com", email["to"]
      assert_equal "Duck", email["subject"]
      assert_equal "<p>Duck</p>", email["html_body"]
    end
  end

  def test_single_part_html_mail_works_through_deliver_and_deliver_batch
    mail = html_mail(html: "<p>Single</p>", single_part: true)

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      delivery_method.deliver!(mail)

      email = JSON.parse(fake_http.last_request.body)["emails"].first
      assert_equal "<p>Single</p>", email["html_body"]
    end

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      delivery_method.deliver_batch!([mail])

      email = JSON.parse(fake_http.last_request.body)["emails"].first
      assert_equal "<p>Single</p>", email["html_body"]
    end
  end

  def test_missing_html_raises_delivery_error
    mail = Mail.new do
      to "recipient@example.com"
      from "sender@example.com"
      subject "Welcome"
      body "plain text only"
    end

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      delivery_method.deliver!(mail)
    end
    assert_equal "No HTML body given. Bento requires an html email body.", error.message

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      delivery_method.deliver_batch!([mail])
    end
    assert_equal "No HTML body given. Bento requires an html email body.", error.message
  end

  def test_module_deliver_batch_uses_given_settings
    mail = html_mail
    settings = {
      publishable_key: "publishable_key",
      secret_key: "secret_key",
      site_uuid: "settings-site"
    }

    with_stubbed_bento_response(http_response(Net::HTTPOK, "200", "OK", "{\"success\":true}")) do |fake_http|
      BentoActionMailer.deliver_batch!([mail], settings)

      body = JSON.parse(fake_http.last_request.body)
      assert_equal "settings-site", body["site_uuid"]
    end
  end

  def test_deliver_batch_raises_delivery_error_on_failed_response
    response = http_response(Net::HTTPForbidden, "403", "Forbidden", "{\"message\":\"Site is not approved\"}")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(response) do
        delivery_method.deliver_batch!([html_mail])
      end
    end

    assert_equal "Bento API request failed (403 Forbidden): Site is not approved", error.message
  end

  def test_send_mail_raises_json_message_from_failed_response
    response = http_response(Net::HTTPForbidden, "403", "Forbidden", "{\"message\":\"Site is not approved\"}")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(response) do
        send_test_mail
      end
    end

    assert_equal "Bento API request failed (403 Forbidden): Site is not approved", error.message
  end

  def test_send_mail_raises_json_error_from_failed_response
    response = http_response(Net::HTTPForbidden, "403", "Forbidden", "{\"error\":\"Author is not approved\"}")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(response) do
        send_test_mail
      end
    end

    assert_equal "Bento API request failed (403 Forbidden): Author is not approved", error.message
  end

  def test_send_mail_raises_joined_json_errors_from_failed_response
    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(unapproved_author_response) do
        send_test_mail
      end
    end

    assert_equal "Bento API request failed (422 Unprocessable Entity): from: is not an approved author", error.message
  end

  def test_send_mail_falls_back_to_response_body_when_error_is_not_json
    response = http_response(Net::HTTPForbidden, "403", "Forbidden", "Forbidden")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(response) do
        send_test_mail
      end
    end

    assert_equal "Bento API request failed (403 Forbidden): Forbidden", error.message
  end

  private

  def html_mail(to: "recipient@example.com", from: "sender@example.com", subject: "Welcome", html: "<p>Hello</p>",
                reply_to: nil, single_part: false)
    mail = Mail.new
    mail.to = to
    mail.from = from
    mail.subject = subject
    mail.reply_to = reply_to if reply_to

    if single_part
      mail.content_type = "text/html; charset=UTF-8"
      mail.body = html
    else
      mail.html_part = Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body html
      end
    end

    mail
  end

  def send_test_mail(reply_to: nil)
    delivery_method.send(
      :send_mail,
      to: "recipient@example.com",
      from: "sender@example.com",
      subject: "Welcome",
      html_body: "<p>Hello</p>",
      reply_to: reply_to
    )
  end

  def delivery_method
    BentoActionMailer::DeliveryMethod.new(
      publishable_key: "publishable_key",
      secret_key: "secret_key",
      site_uuid: "site_test"
    )
  end

  def with_stubbed_bento_response(response)
    fake_http = FakeHttp.new(response)

    Net::HTTP.stub(:start, lambda do |host, port, options, &block|
      assert_equal "app.bentonow.com", host
      assert_equal 443, port
      assert_equal({ use_ssl: true }, options)

      block.call(fake_http)
    end) do
      yield fake_http
    end
  end

  def http_response(response_class, code, message, body)
    response = response_class.new("1.1", code, message)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def unapproved_author_response
    http_response(
      Net::HTTPUnprocessableEntity,
      "422",
      "Unprocessable Entity",
      "{\"errors\":[{\"field\":\"from\",\"message\":\"is not an approved author\"}]}"
    )
  end
end
