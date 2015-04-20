require 'spec_helper'
require 'rubyhorn'

describe "MatterhornAdapter" do
  before(:all) do
    Rubyhorn.init(environment: 'test')
    ActiveEncode::Base.engine_adapter = :matterhorn
  end
  after(:all) do
    ActiveEncode::Base.engine_adapter = :inline
  end

  after do
    subject.purge!
  end

  let (:file) { "file://#{File.absolute_path('spec/fixtures/Bars_512kb.mp4')}" }
  let (:encode) { ActiveEncode::Base.create(file) }

  describe "#create" do
    subject { encode }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.not_to be_empty }
    it { is_expected.to be_running }
  end

  describe "#find" do
    subject { ActiveEncode::Base.find(encode.id) }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq encode.id }
    its(:state) { is_expected.not_to be_nil }
  end

  describe "#cancel!" do
    subject { encode.cancel! }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq encode.id }
    its(:state) { is_expected.to eq :cancelled }
  end

  describe "#purge!" do
    subject { encode.purge! }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq encode.id }
    its(:state) { is_expected.to eq :cancelled }
  end

  describe "reload" do
    subject { encode.reload }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq encode.id }
    its(:state) { is_expected.not_to be_nil }
  end
end
