# frozen_string_literal: true

require "thor"

module SDL
  class CLI < Thor
    DEFAULT_CONFIG_PATH = File.expand_path("~/.config/sdl.yml")

    def initialize(*args, config_path: nil, **kwargs)
      super(*args, **kwargs)
      @config_path = config_path || ENV["SDL_CONFIG_PATH"] || DEFAULT_CONFIG_PATH
    end

    no_commands do
      def current_config
        @config ||= SDL::Config.load(@config_path)
      end

      def client
        SDL::Client.new(
          host: current_config.host,
          username: current_config.username,
          password: current_config.password,
          op_item_name: current_config.op_item_name
        )
      end
    end

    desc "version", "Display the SDL tool version"
    def version
      puts SDL::VERSION
    end

    desc "config", "Display the current configuration"
    def config
      puts "Host: #{current_config.host}"
      puts "Username: #{current_config.username}"
      puts "Password: #{current_config.password ? "[REDACTED]" : "Not set"}"
    end

    desc "connect", "Verify connectivity and authentication with the server"
    def connect
      sid = client.authenticate
      if sid
        puts "Connection successful. Session ID: #{sid}"
      else
        puts "Connection failed. Please check your credentials or server status."
        exit 1
      end
    end

    def self.exit_on_failure?
      true
    end
  end
end
