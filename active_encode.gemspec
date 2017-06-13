# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_encode/version'

Gem::Specification.new do |spec|
  spec.name          = "active_encode"
  spec.version       = ActiveEncode::VERSION
  spec.authors       = ["Michael Klein, Chris Colvard"]
  spec.email         = ["mbklein@gmail.com, chris.colvard@gmail.com"]
  spec.summary       = 'Declare encode job classes that can be run by a variety of encoding services'
  spec.description   = 'This gem serves as the basis for the interface between a Ruby (Rails) application and a provider of transcoding services such as Opencast Matterhorn, Zencoder, and Amazon Elastic Transcoder.'
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-its", "~> 1.2"
end
