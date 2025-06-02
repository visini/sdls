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
