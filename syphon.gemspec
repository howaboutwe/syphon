$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'syphon/version'

Gem::Specification.new do |gem|
  gem.name          = 'syphon'
  gem.version       = Syphon::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.description   = "Syphon data from an Arel source into ElasticSearch"
  gem.summary       = "Syphon data from an Arel source into ElasticSearch"
  gem.homepage      = 'https://github.com/howaboutwe/syphon'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_dependency 'elasticsearch', '~> 1.0.0'
  gem.add_dependency 'activesupport', '< 5'
  gem.add_dependency 'mysql2', '~> 0.3.12'

  gem.add_development_dependency 'bundler'
end
