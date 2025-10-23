# frozen_string_literal: true

require "test_helper"

class DeliveryMethodInitializationTest < Minitest::Test
  def test_initialize_applies_default_transactional_setting
    delivery_method = BentoActionMailer::DeliveryMethod.new

    assert_equal({ transactional: true }, delivery_method.settings)
  end

  def test_initialize_merges_custom_settings
    delivery_method = BentoActionMailer::DeliveryMethod.new(transactional: false, site_uuid: "uuid")

    assert_equal false, delivery_method.settings[:transactional]
    assert_equal "uuid", delivery_method.settings[:site_uuid]
  end

  def test_initialize_preserves_unknown_settings
    delivery_method = BentoActionMailer::DeliveryMethod.new(custom_option: "custom")

    assert_equal "custom", delivery_method.settings[:custom_option]
    assert_equal true, delivery_method.settings[:transactional]
  end

  def test_settings_are_mutable_for_instance_configuration
    delivery_method = BentoActionMailer::DeliveryMethod.new

    delivery_method.settings[:transactional] = false

    refute delivery_method.settings[:transactional]
  end

  def test_initialize_with_nil_treated_as_defaults
    delivery_method = BentoActionMailer::DeliveryMethod.new(nil)

    assert_equal({ transactional: true }, delivery_method.settings)
  end

  def test_initialize_with_empty_hash_uses_defaults
    delivery_method = BentoActionMailer::DeliveryMethod.new({})

    assert_equal({ transactional: true }, delivery_method.settings)
  end

  def test_initialize_with_string_keys_preserves_values
    delivery_method = BentoActionMailer::DeliveryMethod.new("transactional" => false)

    assert_equal true, delivery_method.settings[:transactional]
    assert_equal false, delivery_method.settings["transactional"]
  end

  def test_initialize_with_invalid_type_raises
    error = assert_raises(TypeError) { BentoActionMailer::DeliveryMethod.new(123) }
    assert_equal "Settings must be provided as a hash-like object", error.message
  end
end

class DeliveryMethodDeliverTest < Minitest::Test
  def setup
    @delivery_method = build_delivery_method
  end

  def test_deliver_with_multipart_mail_extracts_html_and_invokes_send_mail
    mail = build_mail_message(
      to: "user@example.com",
      from: "sender@example.com",
      subject: "Welcome",
      html_body: "<p>Hi there</p>",
      text_body: "Hi there"
    )

    captured_arguments = nil
    @delivery_method.stub(:send_mail, ->(**params) { captured_arguments = params }) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "user@example.com", captured_arguments[:to]
    assert_equal "sender@example.com", captured_arguments[:from]
    assert_equal "Welcome", captured_arguments[:subject]
    assert_equal "<p>Hi there</p>", captured_arguments[:html_body]
    assert_equal({}, captured_arguments[:personalization])
  end

  def test_deliver_supports_html_only_messages
    mail = build_mail_message(text_body: nil, html_body: "<section>Only HTML</section>")

    @delivery_method.stub(:send_mail, ->(**params) { params[:html_body] }) do
      result = @delivery_method.deliver!(mail)
      assert_equal "<section>Only HTML</section>", result
    end
  end

  def test_deliver_raises_when_html_body_missing
    mail = build_text_only_mail

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "No HTML body given. Bento requires an html email body.", error.message
  end

  def test_deliver_raises_when_mail_is_nil
    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.deliver!(nil)
    end

    assert_equal "Mail message is required", error.message
  end

  def test_deliver_raises_when_to_address_missing
    mail = build_mail_message(to: nil)

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "Mail to address is required", error.message
  end

  def test_deliver_raises_when_from_address_missing
    mail = build_mail_message(from: " ")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "Mail from address is required", error.message
  end

  def test_deliver_raises_when_subject_missing
    mail = build_mail_message(subject: " ")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "Mail subject is required", error.message
  end

  def test_deliver_raises_when_body_is_nil
    mail = build_mail_stub(
      to: "user@example.com",
      from: "sender@example.com",
      subject: "Hello",
      body: nil
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) { @delivery_method.deliver!(mail) }
    assert_equal "No HTML body given. Bento requires an html email body.", error.message
  end

  def test_deliver_handles_uppercase_html_content_type
    html_part = Mail::Part.new do
      content_type "TEXT/HTML; charset=UTF-8"
      body "<p>Hi</p>"
    end

    mail = build_mail_with_custom_parts(
      to: "user@example.com",
      from: "sender@example.com",
      subject: "Caps",
      parts: [html_part]
    )

    @delivery_method.stub(:send_mail, ->(**params) { params[:html_body] }) do
      assert_equal "<p>Hi</p>", @delivery_method.deliver!(mail)
    end
  end

  def test_deliver_handles_large_html_payload
    large_html = "<p>#{"A" * 50_000}</p>"
    mail = build_mail_message(html_body: large_html, text_body: nil)

    @delivery_method.stub(:send_mail, ->(**params) { params[:html_body].length }) do
      assert_equal large_html.length, @delivery_method.deliver!(mail)
    end
  end

  def test_deliver_uses_first_recipient_when_multiple_provided
    mail = build_mail_message(
      to: ["first@example.com", "second@example.com"],
      from: "sender@example.com",
      subject: "Recipients",
      html_body: "<p>Hi</p>"
    )

    @delivery_method.stub(:send_mail, ->(**params) { params[:to] }) do
      assert_equal "first@example.com", @delivery_method.deliver!(mail)
    end
  end

  def test_deliver_strips_whitespace_from_addresses
    mail = build_mail_message(
      to: ["   spaced@example.com  "],
      from: " sender@example.com ",
      subject: "Spacing",
      html_body: "<p>Hi</p>"
    )

    @delivery_method.stub(:send_mail, ->(**params) { [params[:to], params[:from]] }) do
      result = @delivery_method.deliver!(mail)
      assert_equal ["spaced@example.com", "sender@example.com"], result
    end
  end

  def test_deliver_allows_special_characters
    mail = fixture_mail(:special_character_mail)

    captured = nil
    @delivery_method.stub(:send_mail, ->(**params) { captured = params }) do
      @delivery_method.deliver!(mail)
    end

    assert_equal "Unicode ✓", captured[:subject]
    assert_equal "büyer+test@example.com", captured[:to]
  end
end

class DeliveryMethodSendMailTest < Minitest::Test
  def setup
    @delivery_method = build_delivery_method
    @response = build_response(202, body: "", message: "Accepted")
  end

  def test_send_mail_builds_request_with_expected_payload
    captured = {}

    with_stubbed_http(@response, captured) do
      @delivery_method.stub(:handle_response, lambda { |res|
        captured[:handled] = res
        :handled
      }) do
        result = @delivery_method.send(
          :send_mail,
          to: "user@example.com",
          from: "sender@example.com",
          subject: "Welcome",
          html_body: "<p>Hello</p>",
          personalization: { first_name: "Test" }
        )
        captured[:result] = result
      end
    end

    request = captured[:request]
    assert_equal "/api/v1/batch/emails", request.path
    assert_equal "application/json", request["content-type"]
    assert request["authorization"].start_with?("Basic ")

    payload = JSON.parse(request.body, symbolize_names: true)
    assert_equal "test-site-uuid", payload[:site_uuid]
    email_payload = payload[:emails].first
    assert_equal "user@example.com", email_payload[:to]
    assert_equal "sender@example.com", email_payload[:from]
    assert_equal "Welcome", email_payload[:subject]
    assert_equal "<p>Hello</p>", email_payload[:html_body]
    assert_equal true, email_payload[:transactional]
    assert_equal({ first_name: "Test" }, email_payload[:personalizations])

    assert_equal BentoActionMailer::DeliveryMethod::BENTO_ENDPOINT.hostname, captured[:host]
    assert_equal BentoActionMailer::DeliveryMethod::BENTO_ENDPOINT.port, captured[:port]
    assert_equal({ use_ssl: true }, captured[:options])

    assert_equal @response, captured[:handled]
    assert_equal :handled, captured[:result]
  end

  def test_send_mail_requires_credentials
    delivery_method = build_delivery_method(publishable_key: " ", secret_key: nil)

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      delivery_method.send(
        :send_mail,
        to: "user@example.com",
        from: "sender@example.com",
        subject: "Welcome",
        html_body: "<p>Hello</p>"
      )
    end

    assert_equal "Delivery setting publishable_key is required", error.message
  end

  def test_send_mail_wraps_network_errors
    exception = Timeout::Error.new("execution expired")

    Net::HTTP.stub(:start, ->(*_) { raise exception }) do
      error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
        @delivery_method.send(
          :send_mail,
          to: "user@example.com",
          from: "sender@example.com",
          subject: "Welcome",
          html_body: "<p>Hello</p>"
        )
      end

      assert_equal "Network error: execution expired", error.message
      assert_nil error.response_code
      assert_equal({ "exception" => "Timeout::Error" }, error.error_details)
    end
  end

  def test_send_mail_wraps_socket_errors
    exception = SocketError.new("host unreachable")

    Net::HTTP.stub(:start, ->(*_) { raise exception }) do
      error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
        @delivery_method.send(
          :send_mail,
          to: "user@example.com",
          from: "sender@example.com",
          subject: "Welcome",
          html_body: "<p>Hello</p>"
        )
      end

      assert_equal "Network error: host unreachable", error.message
      assert_equal({ "exception" => "SocketError" }, error.error_details)
    end
  end

  private

  def with_stubbed_http(response, captured, &block)
    Net::HTTP.stub(:start, lambda do |host, port, options, &block|
      captured[:host] = host
      captured[:port] = port
      captured[:options] = options

      http = Minitest::Mock.new
      http.expect(:request, response) do |request|
        captured[:request] = request
      end

      begin
        block.call(http)
      ensure
        http.verify
      end
    end, &block)
  end
end

class DeliveryMethodUtilityTest < Minitest::Test
  def setup
    @delivery_method = build_delivery_method
  end

  def test_success_response_returns_true_for_2xx
    [200, 202, 299].each do |status|
      assert @delivery_method.send(:success_response?, status), "Expected #{status} to be treated as success"
    end
  end

  def test_success_response_returns_false_outside_success_range
    [199, 300, 503].each do |status|
      refute @delivery_method.send(:success_response?, status), "Expected #{status} to be treated as failure"
    end
  end

  def test_parse_error_response_returns_parsed_json
    response = build_response(422, body: '{"error":"Invalid"}', message: "Unprocessable Entity")
    result = @delivery_method.send(:parse_error_response, response)

    assert_equal({ "error" => "Invalid" }, result)
  end

  def test_parse_error_response_handles_nil_body
    response = build_response(500, body: nil, message: "Internal Server Error")
    assert_nil @delivery_method.send(:parse_error_response, response)
  end

  def test_parse_error_response_handles_empty_body
    response = build_response(500, body: "", message: "Internal Server Error")
    assert_nil @delivery_method.send(:parse_error_response, response)
  end

  def test_parse_error_response_handles_whitespace_body
    response = build_response(500, body: "
	  ", message: "Internal Server Error")
    assert_nil @delivery_method.send(:parse_error_response, response)
  end

  def test_parse_error_response_handles_malformed_json
    response = build_response(500, body: "{", message: "Internal Server Error")
    assert_nil @delivery_method.send(:parse_error_response, response)
  end

  def test_build_delivery_error_populates_fields
    error = @delivery_method.send(
      :build_delivery_error,
      "Client error",
      422,
      { "error" => "Invalid" }
    )

    assert_instance_of BentoActionMailer::DeliveryMethod::DeliveryError, error
    assert_equal "Client error", error.message
    assert_equal 422, error.response_code
    assert_equal({ "error" => "Invalid" }, error.error_details)
  end

  def test_build_delivery_error_allows_nil_details
    error = @delivery_method.send(:build_delivery_error, "Error", 500, nil)

    assert_nil error.error_details
    assert_equal 500, error.response_code
  end
end
