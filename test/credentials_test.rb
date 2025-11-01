# frozen_string_literal: true

require_relative "test_helper"
require "tempfile"

class CredentialsTest < Minitest::Test
  def setup
    # Reset any environment variables that might affect tests
    ENV.delete("SDLS_CONFIG_PATH")
    # Clear memoized CLI availability check
    SDLS::Config.instance_variable_set(:@op_cli_available, nil)
  end

  def test_complete_config_with_username_and_password
    with_temp_config(host: "http://nas.local:5000", username: "config_user", password: "config_pass") do |path|
      config = SDLS::Config.load(path)
      assert_equal "config_user", config.username
      assert_equal "config_pass", config.password
    end
  end

  def test_credentials_from_1password_when_config_missing_both
    config_data = {host: "http://nas.local:5000", op_item_name: "TestItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(true) do
        mock_onepassword_fetch("TestItem", username: "op_user", password: "op_pass") do
          # Create a mock prompt that should never be called since we get both from 1Password
          prompt_mock = Minitest::Mock.new

          out, _ = capture_io do
            config = SDLS::Config.load(path, prompt: prompt_mock)
            assert_equal "op_user", config.username
            assert_equal "op_pass", config.password
          end
          assert_includes out, "Fetching credentials from 1Password"
          assert_includes out, "Successfully retrieved username and password from 1Password"

          prompt_mock.verify # Should have no calls
        end
      end
    end
  end

  def test_username_from_1password_password_from_config
    config_data = {host: "http://nas.local:5000", password: "config_pass", op_item_name: "TestItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(true) do
        # Mock 1Password returning username (we only need username since password is from config)
        mock_onepassword_fetch("TestItem", username: "op_user", password: "op_pass") do
          # No prompt needed since we get username from 1Password and use password from config
          prompt_mock = Minitest::Mock.new

          out, _ = capture_io do
            config = SDLS::Config.load(path, prompt: prompt_mock)
            assert_equal "op_user", config.username
            assert_equal "config_pass", config.password  # Should use config password, not 1Password password
          end
          assert_includes out, "Successfully retrieved username and password from 1Password"

          prompt_mock.verify # Should have no calls
        end
      end
    end
  end

  def test_username_from_config_password_from_1password
    config_data = {host: "http://nas.local:5000", username: "config_user", op_item_name: "TestItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(true) do
        mock_onepassword_fetch("TestItem", username: nil, password: "op_pass") do
          # Create a mock prompt that should never be called since we have username from config
          prompt_mock = Minitest::Mock.new

          out, _ = capture_io do
            config = SDLS::Config.load(path, prompt: prompt_mock)
            assert_equal "config_user", config.username
            assert_equal "op_pass", config.password
          end
          assert_includes out, "Successfully retrieved password from 1Password"

          prompt_mock.verify # Should have no calls
        end
      end
    end
  end

  def test_fallback_to_manual_when_1password_fails
    config_data = {host: "http://nas.local:5000", op_item_name: "NonExistentItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(true) do
        mock_onepassword_fetch("NonExistentItem", username: nil, password: nil) do
          prompt_mock = create_mock_prompt(username: "manual_user", password: "manual_pass")

          out, _ = capture_io do
            config = SDLS::Config.load(path, prompt: prompt_mock)
            assert_equal "manual_user", config.username
            assert_equal "manual_pass", config.password
          end
          assert_includes out, "No credentials found in 1Password item"
          assert_includes out, "No username available, please enter manually"
          assert_includes out, "No password available, please enter manually"

          prompt_mock.verify
        end
      end
    end
  end

  def test_fallback_to_manual_when_1password_cli_unavailable
    config_data = {host: "http://nas.local:5000", op_item_name: "TestItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(false) do
        prompt_mock = create_mock_prompt(username: "manual_user", password: "manual_pass")

        out, _ = capture_io do
          config = SDLS::Config.load(path, prompt: prompt_mock)
          assert_equal "manual_user", config.username
          assert_equal "manual_pass", config.password
        end
        assert_includes out, "No username available, please enter manually"
        assert_includes out, "No password available, please enter manually"

        prompt_mock.verify
      end
    end
  end

  def test_manual_entry_when_no_op_item_name
    config_data = {host: "http://nas.local:5000"}

    with_temp_config(config_data) do |path|
      prompt_mock = create_mock_prompt(username: "manual_user", password: "manual_pass")

      out, _ = capture_io do
        config = SDLS::Config.load(path, prompt: prompt_mock)
        assert_equal "manual_user", config.username
        assert_equal "manual_pass", config.password
      end
      assert_includes out, "No username available, please enter manually"
      assert_includes out, "No password available, please enter manually"

      prompt_mock.verify
    end
  end

  def test_onepassword_error_handling
    config_data = {host: "http://nas.local:5000", op_item_name: "TestItem"}

    with_temp_config(config_data) do |path|
      mock_onepassword_cli_available(true) do
        # Mock Open3.capture3 to raise an exception
        Open3.stub(:capture3, ->(*args) { raise StandardError.new("Command failed") }) do
          prompt_mock = create_mock_prompt(username: "manual_user", password: "manual_pass")

          out, _ = capture_io do
            config = SDLS::Config.load(path, prompt: prompt_mock)
            assert_equal "manual_user", config.username
            assert_equal "manual_pass", config.password
          end
          assert_includes out, "1Password error: Failed to retrieve username from 1Password: Command failed"

          prompt_mock.verify
        end
      end
    end
  end

  def test_config_validation_missing_host
    with_temp_config(username: "test_user", password: "test_pass") do |path|
      assert_raises(SDLS::ConfigError, /missing required keys.*host/) do
        SDLS::Config.load(path)
      end
    end
  end

  def test_config_validation_empty_host
    with_temp_config(host: "", username: "test_user", password: "test_pass") do |path|
      assert_raises(SDLS::ConfigError, /missing required keys.*host/) do
        SDLS::Config.load(path)
      end
    end
  end

  def test_config_file_not_found
    assert_raises(SDLS::ConfigError, /Configuration file not found/) do
      SDLS::Config.load("/nonexistent/path/config.yml")
    end
  end

  def test_invalid_yaml_syntax
    Tempfile.create("sdls_config") do |file|
      file.write("invalid: yaml: content: [")
      file.rewind

      assert_raises(SDLS::ConfigError, /Error parsing configuration file/) do
        SDLS::Config.load(file.path)
      end
    end
  end

  def test_defaults_are_set
    with_temp_config(host: "http://nas.local:5000") do |path|
      prompt_mock = create_mock_prompt(username: "manual_user", password: "manual_pass")

      capture_io do
        config = SDLS::Config.load(path, prompt: prompt_mock)
        assert_nil config.op_item_name
        assert_nil config.op_account
        assert_equal [], config.directories
      end

      prompt_mock.verify
    end
  end

  def test_onepassword_cli_availability_memoization
    # Simulate CLI available via ENV
    ENV["SDLS_FORCE_OP_CLI"] = "true"

    assert SDLS::Config.send(:onepassword_cli_available?)

    # Change ENV, should still return memoized true (i.e., not affected by ENV now)
    ENV["SDLS_FORCE_OP_CLI"] = "false"

    assert SDLS::Config.send(:onepassword_cli_available?)
  ensure
    ENV.delete("SDLS_FORCE_OP_CLI")
    SDLS::Config.instance_variable_set(:@op_cli_available, nil)
  end

  def test_fetch_field_handles_missing_field_gracefully
    mock_onepassword_cli_available(true) do
      # Mock successful command but empty output (field doesn't exist)
      Open3.stub(:capture3, ["", "", mock_success_status]) do
        result = SDLS::Config.send(:fetch_field_from_1password, "TestItem", "nonexistent_field")
        assert_nil result
      end
    end
  end

  def test_fetch_field_handles_command_failure
    mock_onepassword_cli_available(true) do
      # Mock failed command
      Open3.stub(:capture3, ["", "Item not found", mock_failure_status]) do
        result = SDLS::Config.send(:fetch_field_from_1password, "TestItem", "password")
        assert_nil result
      end
    end
  end

  private

  def with_temp_config(data)
    Tempfile.create("sdls_config") do |file|
      file.write(data.to_yaml)
      file.rewind
      yield file.path
    end
  end

  def mock_onepassword_cli_available(available)
    SDLS::Config.stub(:onepassword_cli_available?, available) do
      yield
    end
  end

  def mock_onepassword_fetch(item_name, username: nil, password: nil)
    username_response = username ? [username, "", mock_success_status] : ["", "", mock_failure_status]
    password_response = password ? [password, "", mock_success_status] : ["", "", mock_failure_status]

    Open3.stub(:capture3, lambda do |*args|
      # Args can be: ["op", "item", "get", item_name, "--fields", field, "--reveal"]
      # Or with account: ["op", "item", "get", item_name, "--fields", field, "--reveal", "--account", account]
      # So we find the field by looking for the index after "--fields"
      field = args[args.index("--fields") + 1] if args.include?("--fields")
      case field
      when "username"
        username_response
      when "password"
        password_response
      else
        ["", "Unknown field", mock_failure_status]
      end
    end) do
      yield
    end
  end

  def create_mock_prompt(username:, password:)
    prompt_mock = Minitest::Mock.new
    prompt_mock.expect(:ask, username, ["Please enter your username:"])
    prompt_mock.expect(:mask, password, ["Please enter your password:"])
    prompt_mock
  end

  def mock_success_status
    status = Minitest::Mock.new
    status.expect(:success?, true)
    status
  end

  def mock_failure_status
    status = Minitest::Mock.new
    status.expect(:success?, false)
    status
  end
end
