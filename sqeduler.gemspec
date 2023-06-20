# frozen_string_literal: true

require File.expand_path("lib/sqeduler/version", __dir__)

Gem::Specification.new do |gem|
  gem.name          = "sqeduler"
  gem.version       = Sqeduler::VERSION
  gem.summary       = "Common Sidekiq infrastructure for multi-host applications."
  gem.description   = <<-DESC
  Works with Sidekiq scheduler to provides a highly available scheduler that can be run on
  multiple hosts. Also provides a convenient abstract class for Sidekiq workers.
  DESC
  gem.license       = "Apache"
  gem.authors       = ["Jared Jenkins"]
  gem.email         = "jaredjenkins@squareup.com"
  gem.homepage      = "https://rubygems.org/gems/sqeduler"

  gem.files         = `git ls-files`.split($RS)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "activesupport"
  gem.add_runtime_dependency "redis-namespace"
  gem.add_runtime_dependency "sidekiq", "< 7"
  gem.add_runtime_dependency "sidekiq-scheduler", ">= 2.0", "< 6.0"
end
