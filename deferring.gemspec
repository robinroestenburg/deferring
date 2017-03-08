# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'deferring/version'

Gem::Specification.new do |spec|
  spec.name          = 'deferring'
  spec.version       = Deferring::VERSION
  spec.authors       = ['Robin Roestenburg']
  spec.email         = ['robin@roestenburg.io']
  spec.description   = %q{
    The Deferring gem makes it possible to defer saving ActiveRecord
    associations until the parent object is saved.
  }
  spec.summary       = %q{Defer saving ActiveRecord associations until parent is saved}
  spec.homepage      = 'http://github.com/robinroestenburg/deferring'
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '> 4.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'appraisal'
end
