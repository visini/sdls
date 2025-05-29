# frozen_string_literal: true

require "thor"

module SDL
  class CLI < Thor
    DEFAULT_CONFIG_PATH = File.expand_path("~/.config/sdl.yml")

    def initialize(*args, config_path, **kwargs)
      super(*args, **kwargs)
      @config_path = ENV["SDL_CONFIG_PATH"] || DEFAULT_CONFIG_PATH
    end

    no_commands do
      def current_config
        @config ||= SDL::Config.load(@config_path)
      end
    end

    desc "version", "Show version"
    def version
      puts SDL::VERSION
    end

    desc "config", "Print the current configuration"
    def config
      puts "host: #{current_config.host}"
      puts "username: #{current_config.username}"
      puts "password: #{current_config.password ? "[REDACTED]" : "not set"}"
    end

    def self.exit_on_failure?
      true
    end
  end
end
