require 'spec_helper'

describe ActiveEncode::Polling do
  before do
    class PollingEncode < ActiveEncode::Base
      after_status_update ->(encode) { encode.history << "PollingEncode ran after_status_update" }
      after_error ->(encode) { encode.history << "PollingEncode ran after_error" }
      after_cancelled ->(encode) { encode.history << "PollingEncode ran after_cancelled" }
      after_complete ->(encode) { encode.history << "PollingEncode ran after_complete" }

      def history
        @history ||= []
      end
    end
  end

  after do
    Object.send(:remove_const, :PollingEncode)
  end

  describe 'status_update callback' do
    let(:encode) { PollingEncode.create("sample.mp4") }
    subject { PollingEncode.find(encode.id).history }
    it { is_expected.to include("PollingEncode ran after_status_update") }
  end

  describe 'error callback' do
    let(:encode) { PollingEncode.create("sample.mp4") }
    subject { PollingEncode.find(encode.id).history }
    it { is_expected.to include("PollingEncode ran after_error") }
  end

  describe 'cancelled callback' do
    let(:encode) { PollingEncode.create("sample.mp4") }
    subject { PollingEncode.find(encode.id).history }
    it { is_expected.to include("PollingEncode ran after_cancelled") }
  end

  describe 'complete callback' do
    let(:encode) { PollingEncode.create("sample.mp4") }
    subject { PollingEncode.find(encode.id).history }
    it { is_expected.to include("PollingEncode ran after_complete") }
  end

  describe '#after_create' do
    let(:encode_class) { ActiveEncode::Base }
    let(:encode) { encode_class.create(nil) }

    it "enqueue PollingJob after polling wait time" do
      expect(PollingJob).to have_been_enqueued.with(encode.id, {offset:ActiveEncode::Polling::POLLING_WAIT_TIME })
    end
  end
end
