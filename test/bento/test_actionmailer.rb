# frozen_string_literal: true

require "test_helper"

class FakeHttp
  attr_reader :request

  def initialize(response)
    @response = response
  end

  def request(request)
    @request = request
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

      body = JSON.parse(fake_http.request.body)
      assert_equal "site_test", body["site_uuid"]
      assert_equal "sender@example.com", body["emails"].first["from"]
    end
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
    response = http_response(
      Net::HTTPUnprocessableEntity,
      "422",
      "Unprocessable Entity",
      "{\"errors\":[{\"field\":\"from\",\"message\":\"is not an approved author\"}]}"
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      with_stubbed_bento_response(response) do
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

  def send_test_mail
    delivery_method.send(
      :send_mail,
      to: "recipient@example.com",
      from: "sender@example.com",
      subject: "Welcome",
      html_body: "<p>Hello</p>"
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
    response
  end
end
