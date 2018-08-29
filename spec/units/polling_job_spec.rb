require 'rails_helper'

describe ActiveEncode::PollingJob do
  before do
    class PollingEncode < ActiveEncode::Base
      include ActiveEncode::Polling
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

  describe '#perform' do
    let(:encode_class) { PollingEncode }
    let(:encode) { encode_class.create("sample.mp4") }
    let(:poll) { ActiveEncode::PollingJob.new }
    subject { poll.perform(encode).history }

    context "with job in error" do
      before do
        allow(encode).to receive(:state).and_return(:error)
      end

      it "run after_error" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_error")
      end
    end

    context "with job cancelled" do
      before do
        allow(encode).to receive(:state).and_return(:cancelled)
      end

      it "run after_cancelled" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_cancelled")
      end
    end

    context "with job complete" do
      before do
        allow(encode).to receive(:state).and_return(:complete)
      end

      it "run after_complete" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_complete")
      end
    end

    context "with job running" do
      before do
        allow(encode).to receive(:state).and_return(:running)
      end

      it "enqueue PollingJob after polling wait time" do
        encode
        expect(ActiveEncode::PollingJob).to have_been_enqueued.with(encode)
      end
    end
  end
end
