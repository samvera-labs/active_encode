require 'spec_helper'

describe ActiveEncode::PollingJob do
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

  describe '#perform' do
    let(:encode_class) { ActiveEncode::Base }
    let(:encode) { encode_class.create(nil) }
    let(:poll) { PollingJob.new }
    subject { poll.perform(encode) }

    it { is_expected.to include("PollingEncode ran after_status_update") }

    context "with job in error" do
      # TODO how to set status
      # encode.state = :error
      let(:encode) { encode_class.create(input: "sample.mp4", state: :error) }
      it { is_expected.to include("PollingEncode ran after_error") }

      # before do
      #   allow_any_instance_of(ActiveEncode::Base).to receive(:create!).and_raise(StandardError)
      # end
      # let(:master_file) { FactoryGirl.create(:master_file) }
      # it "sets the status of the master file to FAILED" do
      #   job.perform(master_file.id, nil, {})
      #   master_file.reload
      #   expect(master_file.status_code).to eq('FAILED')
      # end
    end

    context "with job cancelled" do
      # TODO how to set status
      let(:encode) { encode_class.create(input: "sample.mp4", state: :cancelled) }
      it { is_expected.to include("PollingEncode ran after_cancelled") }

      # before do
      #   allow(encode_job).to receive(:id).and_return(nil)
      #   allow_any_instance_of(ActiveEncode::Base).to receive(:create!).and_return(encode_job)
      # end
      # let(:encode_job) { ActiveEncode::Base.new(nil) }
      # let(:master_file) { FactoryGirl.create(:master_file) }
      # it "sets the status of the master file to FAILED" do
      #   job.perform(master_file.id, nil, {})
      #   master_file.reload
      #   expect(master_file.status_code).to eq('FAILED')
      # end
    end

    context "with job complete" do
      # TODO how to set status
      encode.state = :complete
      it { is_expected.to include("PollingEncode ran after_complete") }
    end

    context "with job running" do
      # TODO how to set status
      encode.state = :running
      it "enqueue PollingJob after polling wait time" do
        expect(PollingJob).to have_been_enqueued.with(encode.id, {offset:ActiveEncode::Polling::POLLING_WAIT_TIME })
      end
    end
  end
end
