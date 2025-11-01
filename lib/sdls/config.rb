# frozen_string_literal: true

require "yaml"
require "open3"
require "tty-prompt"

module SDLS
  # Configuration errors
  class ConfigError < StandardError; end

  class OnePasswordError < StandardError; end

  # Core configuration keys that must be present
  REQUIRED_KEYS = %i[host].freeze

  Config = Data.define(:host, :username, :password, :op_item_name, :op_account, :directories) do
    class << self
      def load(path, prompt: nil)
        validate_file_exists!(path)
        data = load_and_parse_yaml(path)
        credentials = resolve_credentials(data, prompt: prompt)

        new(**data.merge(credentials))
      rescue Psych::SyntaxError => e
        raise ConfigError, "Error parsing configuration file (#{path}): #{e.message}"
      end

      private

      def validate_file_exists!(path)
        raise ConfigError, "Configuration file not found: #{path}" unless File.exist?(path)
      end

      def load_and_parse_yaml(path)
        data = YAML.load_file(path)
        data = {} unless data.is_a?(Hash)
        data = symbolize_keys(data)

        validate_required_keys!(data, path)
        set_defaults(data)
      end

      def validate_required_keys!(data, path)
        missing_keys = REQUIRED_KEYS - data.keys
        nil_keys = REQUIRED_KEYS.select { |k| data[k].nil? || data[k].to_s.strip.empty? }

        if missing_keys.any? || nil_keys.any?
          invalid_keys = (missing_keys + nil_keys).uniq
          raise ConfigError, "Configuration file (#{path}) is missing required keys or values: #{invalid_keys.join(", ")}"
        end
      end

      def set_defaults(data)
        data[:op_item_name] ||= nil
        data[:op_account] ||= nil
        data[:directories] ||= []
        data
      end

      def symbolize_keys(hash)
        hash.to_h { |k, v| [k.to_sym, v] }
      end

      def resolve_credentials(data, prompt: nil)
        op_item_name = data[:op_item_name]
        op_account = data[:op_account]

        # Check if we have both username and password from config
        has_config_username = data[:username] && !data[:username].to_s.strip.empty?
        has_config_password = data[:password] && !data[:password].to_s.strip.empty?

        # If we have both credentials from config, use them
        if has_config_username && has_config_password
          return {
            username: data[:username],
            password: data[:password]
          }
        end

        # If 1Password item is specified and we're missing some credentials, try to fetch from there
        if op_item_name && !op_item_name.to_s.strip.empty? && (!has_config_username || !has_config_password)
          onepassword_credentials = fetch_credentials_from_1password(op_item_name, op_account)
          if onepassword_credentials[:success]
            final_username = has_config_username ? data[:username] : onepassword_credentials[:username]
            final_password = has_config_password ? data[:password] : onepassword_credentials[:password]

            # If we still don't have username or password after 1Password, prompt for them
            final_username ||= prompt_for_credential("username", mask: false, prompt: prompt)
            final_password ||= prompt_for_credential("password", mask: true, prompt: prompt)

            return {
              username: final_username,
              password: final_password
            }
          end
        end

        # Fallback to config file and manual entry
        {
          username: resolve_username(data[:username], nil, prompt: prompt),
          password: resolve_password(data[:password], nil, prompt: prompt)
        }
      end

      def resolve_username(config_username, op_username, prompt: nil)
        # Priority 1: 1Password username if available
        return op_username if op_username && !op_username.strip.empty?

        # Priority 2: Config file username if available
        return config_username if config_username && !config_username.strip.empty?

        # Priority 3: Manual entry
        prompt_for_credential("username", mask: false, prompt: prompt)
      end

      def resolve_password(config_password, op_password, prompt: nil)
        # Priority 1: 1Password password if available
        return op_password if op_password && !op_password.strip.empty?

        # Priority 2: Config file password if available
        return config_password if config_password && !config_password.strip.empty?

        # Priority 3: Manual entry
        prompt_for_credential("password", mask: true, prompt: prompt)
      end

      def fetch_credentials_from_1password(op_item_name, op_account = nil)
        return {success: false} unless onepassword_cli_available?

        puts "Fetching credentials from 1Password for item: #{op_item_name}..."

        username = fetch_field_from_1password(op_item_name, "username", op_account)
        password = fetch_field_from_1password(op_item_name, "password", op_account)

        puts "1Password item '#{op_item_name}' retrieved successfully."
        puts "Username: #{username.nil? ? "not found" : username}"

        if username || password
          success_msg = []
          success_msg << "username" if username
          success_msg << "password" if password
          puts "Successfully retrieved #{success_msg.join(" and ")} from 1Password"

          {success: true, username: username, password: password}
        else
          puts "No credentials found in 1Password item"
          {success: false}
        end
      rescue OnePasswordError => e
        puts "1Password error: #{e.message}"
        {success: false}
      rescue => e
        puts "Unexpected error fetching credentials from 1Password: #{e.message}"
        {success: false}
      end

      def fetch_field_from_1password(op_item_name, field, op_account = nil)
        cmd = ["op", "item", "get", op_item_name, "--fields", field, "--reveal"]
        cmd += ["--account", op_account] if op_account && !op_account.to_s.strip.empty?

        stdout, _, status = Open3.capture3(*cmd)

        if status.success? && !stdout.strip.empty?
          stdout.strip
        end
      rescue => e
        raise OnePasswordError, "Failed to retrieve #{field} from 1Password: #{e.message}"
      end

      def onepassword_cli_available?
        return @op_cli_available unless @op_cli_available.nil?

        @op_cli_available = if ENV.key?("SDLS_FORCE_OP_CLI")
          ENV["SDLS_FORCE_OP_CLI"] == "true"
        else
          system("which op > /dev/null 2>&1")
        end
      end

      def prompt_for_credential(type, mask: false, prompt: nil)
        puts "No #{type} available, please enter manually:"
        prompt ||= TTY::Prompt.new

        if mask
          prompt.mask("Please enter your #{type}:")
        else
          prompt.ask("Please enter your #{type}:")
        end
      end
    end
  end
end
