require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
Bundler.setup

require 'byebug'
require 'rspec/its'
require 'active_encode'

RSpec.configure do |_config|
end

RSpec::Matchers.define :be_the_same_time_as do |expected|
  match do |actual|
    expect(Time.parse(expected)).to eq(Time.parse(actual))
  end
end
