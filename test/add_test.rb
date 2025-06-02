# frozen_string_literal: true

require_relative "test_helper"
require "webmock/minitest"

class AddTest < Minitest::Test
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
        - NAS/01_documents
        - NAS/02_archive
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

    @download_params = {
      "api" => "SYNO.DownloadStation.Task",
      "version" => "1",
      "method" => "create",
      "session" => "DownloadStation",
      "_sid" => "test_session_id_12345"
    }
  end

  def teardown
    WebMock.disable!
    @temp_config&.unlink
    ENV.delete("SDLS_CONFIG_PATH")
    ENV.delete("SDLS_FORCE_OP_CLI")
  end

  def test_add_success_with_directory_selection
    magnet_link = "magnet:?xt=urn:btih:example123&dn=test.torrent"

    stub_auth_success

    # Mock successful download creation
    stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
      .with(body: @download_params.merge(
        uri: magnet_link,
        destination: "NAS/01_documents"
      ))
      .to_return(
        status: 200,
        body: {
          success: true
        }.to_json
      )

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/01_documents", [
      "Choose download directory",
      ["NAS/01_documents", "NAS/02_archive"]
    ], default: "NAS/01_documents")

    TTY::Prompt.stub :new, mock_prompt do
      output, _ = capture_io do
        SDLS::CLI.start(["add", magnet_link])
      end

      assert_match(/Download created successfully in NAS\/01_documents/, output.strip)
    end

    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_failure_invalid_magnet_link
    invalid_link = "http://example.com/not-a-magnet"

    _, stderr = capture_io do
      assert_raises SystemExit do
        SDLS::CLI.start(["add", invalid_link])
      end
    end

    assert_match(/Invalid or missing magnet link./, stderr.strip)
    # Should not make any HTTP requests for invalid magnet
    assert_not_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_not_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_failure_authentication_fails
    magnet_link = "magnet:?xt=urn:btih:example123&dn=test.torrent"

    # Mock failed authentication
    stub_auth_failure

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/01_documents",
      [
        "Choose download directory",
        ["NAS/01_documents", "NAS/02_archive"]
      ],
      default: "NAS/01_documents")

    TTY::Prompt.stub :new, mock_prompt do
      _, stderr = capture_io do
        assert_raises SystemExit do
          SDLS::CLI.start(["add", magnet_link])
        end
      end

      assert_match(/Authentication error: Authentication failed:/, stderr)
    end

    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_not_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_failure_download_creation_fails
    magnet_link = "magnet:?xt=urn:btih:example123&dn=test.torrent"

    stub_auth_success

    stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
      .with(body: @download_params.merge(
        uri: magnet_link,
        destination: "NAS/02_archive"
      ))
      .to_return(
        status: 200,
        body: {
          success: false,
          error: {
            code: 400
          }
        }.to_json
      )

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/02_archive", [
      "Choose download directory",
      ["NAS/01_documents", "NAS/02_archive"]
    ], default: "NAS/01_documents")

    TTY::Prompt.stub :new, mock_prompt do
      _, stderr = capture_io do
        assert_raises SystemExit do
          SDLS::CLI.start(["add", magnet_link])
        end
      end

      assert_match(/Download creation failed/, stderr)
    end

    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_failure_http_error_on_download_creation
    magnet_link = "magnet:?xt=urn:btih:example123&dn=test.torrent"

    stub_auth_success

    stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
      .with(body: @download_params.merge(
        uri: magnet_link,
        destination: "NAS/01_documents"
      ))
      .to_return(
        status: 500,
        body: {
          success: false,
          error: {
            code: 500
          }
        }.to_json
      )

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/01_documents", [
      "Choose download directory",
      ["NAS/01_documents", "NAS/02_archive"]
    ], default: "NAS/01_documents")

    TTY::Prompt.stub :new, mock_prompt do
      _, stderr = capture_io do
        assert_raises SystemExit do
          SDLS::CLI.start(["add", magnet_link])
        end
      end

      assert_match(/Download creation failed/, stderr)
    end

    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_with_otp_required
    magnet_link = "magnet:?xt=urn:btih:example123&dn=test.torrent"

    # Mock first auth response requiring OTP
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

    # Mock second auth response with OTP that succeeds
    stub_request(:post, "http://nas.local:5000/webapi/auth.cgi")
      .with(
        body: @auth_params.merge("otp_code" => "123456")
      )
      .to_return(
        status: 200,
        body: {
          success: true,
          data: {
            sid: "test_session_id_with_otp"
          }
        }.to_json
      )

    # Mock successful download creation
    stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
      .with(body: @download_params.merge(
        uri: magnet_link,
        destination: "NAS/01_documents",
        _sid: "test_session_id_with_otp"
      ))
      .to_return(
        status: 200,
        body: {
          success: true
        }.to_json
      )

    ENV["SDLS_FORCE_OP_CLI"] = "true" # Simulate 1Password CLI available

    mock_status = Minitest::Mock.new
    mock_status.expect(:success?, true)

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/01_documents", [
      "Choose download directory",
      ["NAS/01_documents", "NAS/02_archive"]
    ], default: "NAS/01_documents")

    Open3.stub :capture3, ["123456\n", "", mock_status] do
      TTY::Prompt.stub :new, mock_prompt do
        output, _ = capture_io do
          SDLS::CLI.start(["add", magnet_link])
        end

        assert_match(/OTP required for authentication\./, output)
        assert_match(/Fetching OTP from 1Password\.\.\./, output)
        assert_match(/Download created successfully in NAS\/01_documents/, output)
      end
    end

    mock_status.verify
    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi", times: 2
    assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  def test_add_reads_magnet_from_clipboard_when_not_provided
    magnet_link = "magnet:?xt=urn:btih:fromclipboard&dn=clipboard-test"

    Clipboard.stub :paste, magnet_link do
      stub_auth_success

      stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
        .with(body: @download_params.merge(
          uri: magnet_link,
          destination: "NAS/01_documents"
        ))
        .to_return(
          status: 200,
          body: {
            success: true
          }.to_json
        )

      mock_prompt = Minitest::Mock.new
      mock_prompt.expect(:select, "NAS/01_documents", [
        "Choose download directory",
        ["NAS/01_documents", "NAS/02_archive"]
      ], default: "NAS/01_documents")

      TTY::Prompt.stub :new, mock_prompt do
        output, _ = capture_io do
          SDLS::CLI.start(["add"])
        end

        assert_match(/Download created successfully in NAS\/01_documents/, output)
      end

      mock_prompt.verify
      assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
      assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
    end
  end

  def test_add_prints_torrent_name
    magnet_link = "magnet:?xt=urn:btih:abc123&dn=Important.Research.Archive.zip"

    stub_auth_success

    stub_request(:post, "http://nas.local:5000/webapi/DownloadStation/task.cgi")
      .with(body: hash_including(uri: magnet_link))
      .to_return(
        status: 200,
        body: {success: true}.to_json
      )

    mock_prompt = Minitest::Mock.new
    mock_prompt.expect(:select, "NAS/01_documents", [
      "Choose download directory",
      ["NAS/01_documents", "NAS/02_archive"]
    ], default: "NAS/01_documents")

    TTY::Prompt.stub :new, mock_prompt do
      output, _ = capture_io do
        SDLS::CLI.start(["add", magnet_link])
      end

      assert_match(/Adding torrent: Important\.Research\.Archive\.zip/, output)
      assert_match(/Download created successfully/, output)
    end

    mock_prompt.verify
    assert_requested :post, "http://nas.local:5000/webapi/auth.cgi"
    assert_requested :post, "http://nas.local:5000/webapi/DownloadStation/task.cgi"
  end

  private

  def stub_auth_success
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
  end

  def stub_auth_failure
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
  end
end
