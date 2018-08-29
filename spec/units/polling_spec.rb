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
    let(:encode) { encode_class.create("sample.mp4") }

    it "enqueue PollingJob after polling wait time" do
      # expect(ActiveEncode::PollingJob).to have_been_enqueued.with(encode.id, {offset:ActiveEncode::Polling::POLLING_WAIT_TIME })
      expect(ActiveEncode::PollingJob).to have_been_enqueued.with(encode.id)
      expect(ActiveEncode::PollingJob).to have_been_enqueued.at(ActiveEncode::Polling::POLLING_WAIT_TIME.from_now)
    end
  end
end
