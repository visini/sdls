# frozen_string_literal: true

require_relative "test_helper"
require "webmock/minitest"

class ConnectTest < Minitest::Test
  def setup
    WebMock.enable!
    WebMock.reset!

    # Create a temporary config file for testing
    @temp_config = Tempfile.new("sdls_config")
    @temp_config.write <<~YAML
      host: http://nas.local:5000
      username: test_user
      password: test_pass
      op_item_name: MyItem
      directories:
        - test/dir
        - another
    YAML
    @temp_config.rewind
    @temp_config.close

    ENV["SDLS_CONFIG_PATH"] = @temp_config.path

    @auth_params = {
      "account" => "test_user",
      "api" => "SYNO.API.Auth",
      "format" => "cookie",
      "method" => "login",
      "passwd" => "test_pass",
      "session" => "FileStation",
      "version" => "6"
    }
  end

  def teardown
    WebMock.disable!
    @temp_config&.unlink
    ENV.delete("SDLS_CONFIG_PATH")
    ENV.delete("SDLS_FORCE_OP_CLI")
  end

  def test_connect_success
    # Mock successful authentication response
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: @auth_params
      )
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            sid: "test_session_id_12345"
          }
        }.to_json
      )

    output, _ = capture_io do
      SDLS::CLI.start(["connect"])
    end

    assert_match(/Connection successful. Session ID: test_ses\.\.\./, output.strip)
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
  end

  def test_connect_failure_invalid_credentials
    # Mock failed authentication response
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
          body: @auth_params
        )
      .to_return(
        status: 200,
        body: {
          success: false,
          error: {
            code: 400
          }
        }.to_json
      )

    output, _ = capture_io do
      assert_raises SystemExit do
        SDLS::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
  end

  def test_connect_failure_http_error
    # Mock HTTP error response
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: hash_including("account" => "test_user")
      )
      .to_return(status: 500)

    output, _ = capture_io do
      assert_raises SystemExit do
        SDLS::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
  end

  def test_connect_failure_network_error
    # Mock network error
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(body: hash_including("account" => "test_user"))
      .to_raise(SocketError.new("Connection refused"))

    output, _ = capture_io do
      assert_raises SystemExit do
        SDLS::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
  end

  def test_connect_with_otp_required_1password_available
    # First response requires OTP
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: @auth_params
      )
      .to_return(
        status: 200,
        body: {
          success: false,
          error: {
            code: 400,
            errors: {
              types: [{type: "otp"}]
            }
          }
        }.to_json
      )

    # Second response with OTP
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: hash_including("otp_code" => "123456")
      )
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {sid: "test_session_id_with_otp"}
        }.to_json
      )

    # Mock successful 1Password OTP retrieval using Minitest::Mock
    mock_status = Minitest::Mock.new
    mock_status.expect(:success?, true)

    ENV["SDLS_FORCE_OP_CLI"] = "true" # Simulate 1Password CLI available

    Open3.stub :capture3, ["123456\n", "", mock_status] do
      output, _ = capture_io do
        SDLS::CLI.start(["connect"])
      end

      assert_match(/OTP required for authentication\./, output.strip)
      assert_match(/Fetching OTP from 1Password\.\.\./, output.strip)
      assert_match(/Connection successful. Session ID: test_ses\.\.\./, output.strip)
      assert_requested :post, "http://nas.local:5000/webapi/auth.cgi", times: 2
    end

    mock_status.verify
  end

  def test_connect_with_otp_required_manual_fallback
    # Create a config without op_item_name
    temp_config = Tempfile.new("sdls_config_no_op")
    temp_config.write <<~YAML
      host: http://nas.local:5000
      username: test_user
      password: test_pass
      directories:
        - test/dir
        - another
    YAML
    temp_config.rewind
    temp_config.close

    ENV["SDLS_CONFIG_PATH"] = temp_config.path

    # Mock first response requiring OTP
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: @auth_params
      )
      .to_return(
        status: 200,
        body: {
          success: false,
          error: {
            code: 400,
            errors: {
              types: [{type: "otp"}]
            }
          }
        }.to_json
      )

    # Mock second response with OTP that succeeds
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: @auth_params.merge("otp_code" => "654321")
      )
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            sid: "test_session_id_manual_otp"
          }
        }.to_json
      )

    # Mock manual OTP input using tty-prompt
    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:mask, "654321", ["Please enter your OTP code:"])

    TTY::Prompt.stub :new, mock_prompt do
      output, _ = capture_io do
        SDLS::CLI.start(["connect"])
      end

      assert_match(/OTP required for authentication\./, output.strip)
      assert_match(/Connection successful. Session ID: test_ses\.\.\./, output.strip)
      assert_requested :post, "http://nas.local:5000/webapi/auth.cgi", times: 2
    end

    mock_prompt.verify
    temp_config.unlink
  end
end
