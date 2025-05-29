# frozen_string_literal: true

require_relative "test_helper"

class VersionTest < Minitest::Test
  def test_version_output
    output, _ = capture_io do
      SDL::CLI.start(["version"])
    end

    assert_match(/\d+\.\d+\.\d+/, output.strip)
  end
end
