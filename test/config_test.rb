# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_config_output
    Tempfile.create("sdls_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        username: test_user
        password: test_pass
        directories:
          - test/dir
          - another
      YAML
      file.rewind

      ENV["SDLS_CONFIG_PATH"] = file.path

      output, _ = capture_io do
        SDLS::CLI.start(["config"])
      end

      assert_equal <<~OUTPUT, output
        Current config:
          host: http://nas.local:5000
          username: test_user
          password: [REDACTED]
          op_item_name: [NOT SET]
          op_account: [NOT SET]
          directories: test/dir, another
      OUTPUT
    ensure
      ENV.delete("SDLS_CONFIG_PATH")
    end
  end

  def test_config_loading_with_missing_credentials_but_op_item_name
    Tempfile.create("sdls_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        op_item_name: MyItem
        directories:
          - test/dir
      YAML
      file.rewind

      # Mock 1Password CLI to return credentials
      SDLS::Config.stub(:onepassword_cli_available?, true) do
        Open3.stub(:capture3, lambda do |*args|
          # Args: ["op", "item", "get", item_name, "--fields", field, "--reveal"]
          # So field is at index -2 (second to last)
          field = args[-2]
          case field
          when "username"
            ["op_user\n", "", mock_success_status]
          when "password"
            ["op_password\n", "", mock_success_status]
          else
            ["", "Unknown field", mock_failure_status]
          end
        end) do
          # Create a mock prompt that should never be called since we get both from 1Password
          prompt_mock = Minitest::Mock.new

          capture_io do
            config = SDLS::Config.load(file.path, prompt: prompt_mock)
            assert_equal "http://nas.local:5000", config.host
            assert_equal "op_user", config.username
            assert_equal "op_password", config.password
            assert_equal "MyItem", config.op_item_name
          end

          prompt_mock.verify # Should have no calls
        end
      end
    end
  end

  def test_config_output_with_op_account
    Tempfile.create("sdls_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        username: test_user
        password: test_pass
        op_item_name: MyItem
        op_account: my.1password.com
        directories:
          - test/dir
      YAML
      file.rewind

      ENV["SDLS_CONFIG_PATH"] = file.path

      output, _ = capture_io do
        SDLS::CLI.start(["config"])
      end

      assert_equal <<~OUTPUT, output
        Current config:
          host: http://nas.local:5000
          username: test_user
          password: [REDACTED]
          op_item_name: MyItem
          op_account: my.1password.com
          directories: test/dir
      OUTPUT
    ensure
      ENV.delete("SDLS_CONFIG_PATH")
    end
  end

  def test_config_loading_with_op_account
    Tempfile.create("sdls_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        op_item_name: MyItem
        op_account: my.1password.com
        directories:
          - test/dir
      YAML
      file.rewind

      # Track command arguments to verify --account flag is included
      captured_commands = []

      # Mock 1Password CLI to return credentials and capture commands
      SDLS::Config.stub(:onepassword_cli_available?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_commands << args
          # Args: ["op", "item", "get", item_name, "--fields", field, "--reveal", "--account", account]
          field = args[args.index("--fields") + 1] if args.include?("--fields")
          case field
          when "username"
            ["op_user\n", "", mock_success_status]
          when "password"
            ["op_password\n", "", mock_success_status]
          else
            ["", "Unknown field", mock_failure_status]
          end
        end) do
          # Create a mock prompt that should never be called since we get both from 1Password
          prompt_mock = Minitest::Mock.new

          capture_io do
            config = SDLS::Config.load(file.path, prompt: prompt_mock)
            assert_equal "http://nas.local:5000", config.host
            assert_equal "op_user", config.username
            assert_equal "op_password", config.password
            assert_equal "MyItem", config.op_item_name
            assert_equal "my.1password.com", config.op_account
          end

          # Verify that --account flag was included in the op commands
          assert_equal 2, captured_commands.length, "Should have made 2 op calls (username and password)"
          captured_commands.each do |cmd|
            assert_includes cmd, "--account", "Command should include --account flag"
            assert_includes cmd, "my.1password.com", "Command should include the account value"
          end

          prompt_mock.verify # Should have no calls
        end
      end
    end
  end

  def test_config_loading_without_op_account_omits_flag
    Tempfile.create("sdls_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        op_item_name: MyItem
        directories:
          - test/dir
      YAML
      file.rewind

      # Track command arguments to verify --account flag is NOT included
      captured_commands = []

      # Mock 1Password CLI to return credentials and capture commands
      SDLS::Config.stub(:onepassword_cli_available?, true) do
        Open3.stub(:capture3, lambda do |*args|
          captured_commands << args
          field = args[args.index("--fields") + 1] if args.include?("--fields")
          case field
          when "username"
            ["op_user\n", "", mock_success_status]
          when "password"
            ["op_password\n", "", mock_success_status]
          else
            ["", "Unknown field", mock_failure_status]
          end
        end) do
          prompt_mock = Minitest::Mock.new

          capture_io do
            config = SDLS::Config.load(file.path, prompt: prompt_mock)
            assert_nil config.op_account
          end

          # Verify that --account flag was NOT included in the op commands
          assert_equal 2, captured_commands.length, "Should have made 2 op calls (username and password)"
          captured_commands.each do |cmd|
            refute_includes cmd, "--account", "Command should NOT include --account flag when op_account is not set"
          end

          prompt_mock.verify
        end
      end
    end
  end

  private

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
