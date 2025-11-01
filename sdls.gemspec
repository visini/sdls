# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "sdls"
  s.version = "0.1.3"
  s.required_ruby_version = ">= 3.4"
  s.summary = "Synology Download Station CLI"
  s.description = "A command-line interface for managing downloads on Synology Download Station."
  s.authors = ["Camillo Visini"]
  s.homepage = "https://github.com/visini/sdls"
  s.license = "MIT"
  s.files = Dir["lib/**/*.rb"] + Dir["bin/*"]
  s.bindir = "bin"
  s.executables = ["sdls"]

  s.add_dependency "thor", "~> 1.3"
  s.add_dependency "tty-prompt", "~> 0.23"
  s.add_dependency "clipboard", "~> 2.0"
end
