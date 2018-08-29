require 'rails_helper'

describe ActiveEncode::Polling do
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

  describe '#after_create' do
    let(:encode_class) { PollingEncode }
    subject { encode_class.create("sample.mp4") }

    it "enqueue PollingJob after polling wait time" do
      subject
      expect(ActiveEncode::PollingJob).to have_been_enqueued.with(subject)
    end
  end
end
