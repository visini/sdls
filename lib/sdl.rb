require "thor"

module SDL
  class CLI < Thor
    desc "hello NAME", "Say hello to NAME"
    def hello(name)
      puts "Hello, #{name}!"
    end

    def self.exit_on_failure?
      true # Exit with a non-zero status code on failure
    end
  end
end
