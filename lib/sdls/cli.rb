# frozen_string_literal: true

require "thor"
require "tty-prompt"

module SDLS
  class CLI < Thor
    DEFAULT_CONFIG_PATH = File.expand_path("~/.config/sdls.yml")

    def initialize(*args, config_path: nil, **kwargs)
      super(*args, **kwargs)
      @config_path = config_path || ENV["SDLS_CONFIG_PATH"] || DEFAULT_CONFIG_PATH
    end

    no_commands do
      def current_config
        @config ||= SDLS::Config.load(@config_path)
      end

      def client
        SDLS::Client.new(
          host: current_config.host,
          username: current_config.username,
          password: current_config.password,
          op_item_name: current_config.op_item_name
        )
      end
    end

    desc "version", "Display the SDLS tool version"
    def version
      puts SDLS::VERSION
    end

    desc "config", "Display the current configuration"
    def config
      puts "Current config:"
      puts "  host: #{current_config.host}"
      puts "  username: #{current_config.username}"
      puts "  password: [REDACTED]"
      puts "  op_item_name: #{current_config.op_item_name}" if current_config.op_item_name
      puts "  directories: #{current_config.directories.join(", ")}" if current_config.directories.any?
    end

    desc "connect", "Verify connectivity and authentication with the server"
    def connect
      sid = client.authenticate
      if sid
        puts "Connection successful. Session ID: #{sid.slice(0, 8)}..."
      else
        puts "Connection failed. Please check your credentials or server status."
        exit 1
      end
    end

    desc "add MAGNET", "Add a magnet link to Synology Download Station"
    def add(magnet)
      unless magnet.start_with?("magnet:")
        warn "Invalid magnet link."
        exit 1
      end

      prompt = TTY::Prompt.new
      destination = prompt.select("Choose download directory", current_config.directories, default: current_config.directories.first)

      success = client.create_download(magnet: magnet, destination: destination)
      exit 1 unless success
    end

    def self.exit_on_failure?
      true
    end
  end
end
