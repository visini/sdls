Gem::Specification.new do |s|
  s.name = "sdls"
  s.version = "0.1.0"
  s.required_ruby_version = ">= 3.4"
  s.summary = "Synology Download Station CLI"
  s.description = "A command-line interface for managing downloads on Synology Download Station."
  s.authors = ["Camillo Visini"]
  s.executables = ["sdls"]
  s.bindir = "bin"
  s.files = Dir["lib/**/*.rb"] + Dir["bin/*"]
  s.homepage = "https://github.com/visini/sdls"
  s.license = "MIT"
end
