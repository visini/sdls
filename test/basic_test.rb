require_relative "test_helper"

class BasicTest < Minitest::Test
  def test_hello
    output = capture_io do
      SDL::CLI.start(["hello", "world"])
    end

    assert_equal "Hello, world!\n", output.first
  end
end
