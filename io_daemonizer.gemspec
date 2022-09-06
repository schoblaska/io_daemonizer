Gem::Specification.new do |s|
  s.name = "io_daemonizer"
  s.version = "4"
  s.summary = "IO Daemonizer"
  s.description =
    "Wrap a Ruby script that speaks IO in a daemon so that you only pay the startup overhead once."
  s.authors = ["Joey Schoblaska"]
  s.email = "joey.schoblaska@gmail.com"
  s.files = ["io_daemonizer.rb"]
  s.homepage = "https://github.com/joeyschoblaska/io_daemonizer"
  s.license = "MIT"
end
