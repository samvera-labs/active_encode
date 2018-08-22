require 'spec_helper'

describe ActiveEncode::Polling do
  describe '#after_create' do
    let(:encode_class) { ActiveEncode::Base }
    let(:encode) { encode_class.create(nil) }

    it "enqueue PollingJob after polling wait time" do
      # TODO
      expect(PollingJob).to have_been_enqueued.with(encode.id, {offset:ActiveEncode::Polling::POLLING_WAIT_TIME })
    end
  end
end
