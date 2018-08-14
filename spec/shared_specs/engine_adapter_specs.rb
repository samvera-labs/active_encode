# frozen_string_literal: true
RSpec.shared_examples 'an ActiveEncode::EngineAdapter' do |*_flags|
  it { is_expected.to respond_to :create }
  it { is_expected.to respond_to :find }
  it { is_expected.to respond_to :list }
  it { is_expected.to respond_to :cancel }
end
