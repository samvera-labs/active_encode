# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_encode/version'

Gem::Specification.new do |spec|
  spec.name          = "active_encode"
  spec.version       = ActiveEncode::VERSION
  spec.authors       = ["Michael Klein, Chris Colvard, Phuong Dinh"]
  spec.email         = ["mbklein@gmail.com, chris.colvard@gmail.com, phuongdh@gmail.com"]
  spec.summary       = 'Declare encode job classes that can be run by a variety of encoding services'
  spec.description   = 'This gem provides an interface to transcoding services such as Ffmpeg, Amazon Elastic Transcoder, or Amazon Elemental MediaConvert.'
  spec.homepage      = "https://github.com/samvera-labs/active_encode"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata      = { "rubygems_mfa_required" => "true" }

  spec.add_dependency "rails"
  spec.add_dependency "addressable", "~> 2.8"

  spec.add_development_dependency "aws-sdk-cloudwatchevents"
  spec.add_development_dependency "aws-sdk-cloudwatchlogs"
  spec.add_development_dependency "aws-sdk-core", "<= 3.220.0"
  spec.add_development_dependency "aws-sdk-elastictranscoder"
  spec.add_development_dependency "aws-sdk-mediaconvert"
  spec.add_development_dependency "aws-sdk-s3"
  spec.add_development_dependency "bixby", '~> 5.0', '>= 5.0.2'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "engine_cart", "~> 2.2"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency "rspec-rails"
end
