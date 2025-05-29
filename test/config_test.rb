# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_config_output
    Tempfile.create("sdl_config") do |file|
      file.write <<~YAML
        host: http://nas.local:5000
        username: test_user
        password: test_pass
      YAML
      file.rewind

      ENV["SDL_CONFIG_PATH"] = file.path

      output, _ = capture_io do
        SDL::CLI.start(["config"])
      end

      assert_equal <<~OUTPUT, output
        host: http://nas.local:5000
        username: test_user
        password: [REDACTED]
      OUTPUT
    ensure
      ENV.delete("SDL_CONFIG_PATH")
    end
  end
end
