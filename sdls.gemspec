# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "sdls"
  s.version = "0.1.0"
  s.required_ruby_version = ">= 3.4"
  s.summary = "Synology Download Station CLI"
  s.description = "A command-line interface for managing downloads on Synology Download Station."
  s.authors = ["Camillo Visini"]
  s.homepage = "https://github.com/visini/sdls"
  s.license = "MIT"
  s.files = Dir["lib/**/*.rb"] + Dir["bin/*"]
  s.bindir = "bin"
  s.executables = ["sdls"]

  s.add_dependency "thor"
  s.add_dependency "tty-prompt"
  s.add_dependency "clipboard"
end
