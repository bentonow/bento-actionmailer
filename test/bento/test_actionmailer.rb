# frozen_string_literal: true

require "test_helper"

class BentoActionMailerTest < Minitest::Test
  ResponseMock = Struct.new(:code, :body, :message)

  def setup
    @delivery_method = BentoActionMailer::DeliveryMethod.new(
      site_uuid: "test-uuid",
      publishable_key: "test-publishable-key",
      secret_key: "test-secret-key"
    )
  end

  def test_that_it_has_a_version_number
    refute_nil ::BentoActionMailer::VERSION
  end

  def test_handle_response_allows_successful_statuses
    response = build_response(202, body: "", message: "Accepted")
    assert_nil @delivery_method.send(:handle_response, response)
  end

  def test_authorization_error_for_specific_message
    response = build_response(
      401,
      body: { error: BentoActionMailer::DeliveryMethod::UNAUTHORIZED_AUTHOR_ERROR }.to_json,
      message: "Unauthorized"
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal BentoActionMailer::DeliveryMethod::UNAUTHORIZED_AUTHOR_ERROR, error.message
    assert_equal 401, error.response_code
    assert_equal({ "error" => BentoActionMailer::DeliveryMethod::UNAUTHORIZED_AUTHOR_ERROR }, error.error_details)
  end

  def test_authorization_error_for_generic_message
    response = build_response(
      403,
      body: { error: "API key revoked" }.to_json,
      message: "Forbidden"
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Authorization failed: API key revoked", error.message
    assert_equal 403, error.response_code
    assert_equal({ "error" => "API key revoked" }, error.error_details)
  end

  def test_authorization_error_without_payload_message
    response = build_response(401, body: "", message: nil)

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Authorization failed", error.message
    assert_equal 401, error.response_code
    assert_nil error.error_details
  end

  def test_client_error_with_json_payload
    response = build_response(
      422,
      body: { error: "Validation failed" }.to_json,
      message: "Unprocessable Entity"
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Client error: Validation failed", error.message
    assert_equal 422, error.response_code
    assert_equal({ "error" => "Validation failed" }, error.error_details)
  end

  def test_client_error_without_body_uses_http_message
    response = build_response(404, body: "", message: "Not Found")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Client error: Not Found", error.message
    assert_equal 404, error.response_code
    assert_nil error.error_details
  end

  def test_client_error_with_malformed_json_gracefully_falls_back
    response = build_response(400, body: "{", message: "Bad Request")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Client error: Bad Request", error.message
    assert_equal 400, error.response_code
    assert_nil error.error_details
  end

  def test_server_error_uses_payload_message
    response = build_response(
      503,
      body: { error: "Upstream service unavailable" }.to_json,
      message: "Service Unavailable"
    )

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Bento API server error: Upstream service unavailable", error.message
    assert_equal 503, error.response_code
    assert_equal({ "error" => "Upstream service unavailable" }, error.error_details)
  end

  def test_server_error_without_payload_uses_http_message
    response = build_response(500, body: "", message: "Internal Server Error")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Bento API server error: Internal Server Error", error.message
    assert_equal 500, error.response_code
    assert_nil error.error_details
  end

  def test_unexpected_status_wraps_message
    response = build_response(302, body: "", message: "Found")

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Unexpected response: 302 Found", error.message
    assert_equal 302, error.response_code
    assert_nil error.error_details
  end

  def test_unexpected_status_with_nil_message_uses_unknown_response
    response = build_response(302, body: "", message: nil)

    error = assert_raises(BentoActionMailer::DeliveryMethod::DeliveryError) do
      @delivery_method.send(:handle_response, response)
    end

    assert_equal "Unexpected response: 302 Unknown response", error.message
    assert_equal 302, error.response_code
    assert_nil error.error_details
  end

  private

  def build_response(status, body:, message:)
    ResponseMock.new(status.to_s, body, message)
  end
end
