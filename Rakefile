begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "thin-auth-ntlm"
    gemspec.summary = "Allows you to force NTLM authentication on Thin TCP servers."
    gemspec.author = "Alexey Borzenkov"
    gemspec.email = "snaury@gmail.com"

    gemspec.add_dependency('thin', '>= 1.0.0')
    gemspec.add_dependency('rubysspi-server', '>= 0.0.1')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
