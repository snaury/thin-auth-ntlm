require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "thin-auth-ntlm"
  s.version = "0.0.2"
  s.summary = "Allows you to force NTLM authentication on Thin TCP servers."

  s.add_dependency('thin', '>= 1.0.0')
  s.add_dependency('rubysspi-server', '>= 0.0.1')
  s.files = FileList["lib/**/*", "*.txt", "Rakefile"].to_a
  s.require_path = "lib"

  s.author = "Alexey Borzenkov"
  s.email = "snaury@gmail.com"
  s.extra_rdoc_files = ["README.txt", "LICENSE.txt"]
  s.has_rdoc = true
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end
