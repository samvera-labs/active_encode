require 'rails_helper'

describe ActiveEncode::PollingJob do
  include ActiveJob::TestHelper

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
    let(:encode) { PollingEncode.create("sample.mp4").tap { |encode| encode.state = state } }
    let(:poll) { ActiveEncode::PollingJob.new }
    subject { encode.history }

    before do
      encode
      clear_enqueued_jobs
      poll.perform(encode)
    end

    context "with job in error" do
      let(:state) { :error }

      it "runs after_error" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_error")
      end

      it "does not re-enqueue itself" do
        expect(ActiveEncode::PollingJob).not_to have_been_enqueued
      end
    end

    context "with job cancelled" do
      let(:state) { :cancelled }

      it "runs after_cancelled" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_cancelled")
      end

      it "does not re-enqueue itself" do
        expect(ActiveEncode::PollingJob).not_to have_been_enqueued
      end
    end

    context "with job complete" do
      let(:state) { :complete }

      it "runs after_complete" do
        is_expected.to include("PollingEncode ran after_status_update")
        is_expected.to include("PollingEncode ran after_complete")
      end

      it "does not re-enqueue itself" do
        expect(ActiveEncode::PollingJob).not_to have_been_enqueued
      end
    end

    context "with job running" do
      let(:state) { :running }

      it "runs after_status_update" do
        is_expected.to include("PollingEncode ran after_status_update")
      end

      it "re-enqueues itself" do
        expect(ActiveEncode::PollingJob).to have_been_enqueued.with(encode)
      end
    end
  end
end
