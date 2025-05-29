# frozen_string_literal: true

require_relative "test_helper"
require "webmock/minitest"

class ConnectTest < Minitest::Test
  def setup
    WebMock.enable!
    WebMock.reset!

    # Create a temporary config file for testing
    @temp_config = Tempfile.new("sdl_config")
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

    ENV["SDL_CONFIG_PATH"] = @temp_config.path
  end

  def teardown
    WebMock.disable!
    @temp_config&.unlink
    ENV.delete("SDL_CONFIG_PATH")
  end

  def test_connect_success
    # Mock successful authentication response
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6")
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            sid: "test_session_id_12345"
          }
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    output, _ = capture_io do
      SDL::CLI.start(["connect"])
    end

    assert_match(/Connection successful. Session ID: test_ses\.\.\./, output.strip)
    assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6"
  end

  def test_connect_failure_invalid_credentials
    # Mock failed authentication response
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6")
      .to_return(
        status: 200,
        body: {
          success: false,
          error: {
            code: 400
          }
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    output, _ = capture_io do
      assert_raises SystemExit do
        SDL::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6"
  end

  def test_connect_failure_http_error
    # Mock HTTP error response
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6")
      .to_return(status: 500)

    output, _ = capture_io do
      assert_raises SystemExit do
        SDL::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6"
  end

  def test_connect_failure_network_error
    # Mock network error
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6")
      .to_raise(SocketError.new("Connection refused"))

    output, _ = capture_io do
      assert_raises SystemExit do
        SDL::CLI.start(["connect"])
      end
    end

    assert_match(/Connection failed. Please check your credentials or server status./, output.strip)
    assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6"
  end

  def test_connect_with_otp_required
    # Mock first response requiring OTP
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6")
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
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    # Mock second response with OTP that succeeds
    stub_request(:get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&otp_code=123456&passwd=test_pass&session=FileStation&version=6")
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            sid: "test_session_id_with_otp"
          }
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    # Mock successful 1Password OTP retrieval using Minitest::Mock
    mock_status = Minitest::Mock.new
    mock_status.expect(:success?, true)

    Open3.stub :capture3, ["123456\n", "", mock_status] do
      output, _ = capture_io do
        SDL::CLI.start(["connect"])
      end

      assert_match(/Connection successful. Session ID: test_ses\.\.\./, output.strip)
      assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&passwd=test_pass&session=FileStation&version=6"
      assert_requested :get, "http://nas.local:5000/webapi/auth.cgi?account=test_user&api=SYNO.API.Auth&format=cookie&method=login&otp_code=123456&passwd=test_pass&session=FileStation&version=6"
    end

    mock_status.verify
  end
end
