# frozen_string_literal: true
RSpec.shared_examples 'an ActiveEncode::EngineAdapter' do |*_flags|
  before do
    raise 'adapter must be set with `let(:created_job)`' unless defined? created_job
    raise 'adapter must be set with `let(:running_job)`' unless defined? running_job
    raise 'adapter must be set with `let(:canceled_job)`' unless defined? canceled_job
    raise 'adapter must be set with `let(:completed_job)`' unless defined? completed_job
    raise 'adapter must be set with `let(:failed_job)`' unless defined? failed_job
  end

  it { is_expected.to respond_to :create }
  it { is_expected.to respond_to :find }
  it { is_expected.to respond_to :cancel }

  describe "#create" do
    subject { created_job }

    it 'returns an ActiveEncode::Base object' do
      expect(subject.class).to be ActiveEncode::Base
    end
    its(:id) { is_expected.not_to be_empty }
    it { is_expected.to be_running }
    its(:current_operations) { is_expected.to be_empty }
    its(:percent_complete) { is_expected.to be < 100 }
    its(:errors) { is_expected.to be_empty }
    its(:created_at) { is_expected.to be_kind_of Time }
    its(:updated_at) { is_expected.to be_nil }

    context 'input' do
      subject { created_job.input }

      its(:width) { is_expected.to be_blank }
      its(:height) { is_expected.to be_blank }
      its(:frame_rate) { is_expected.to be_blank }
      its(:duration) { is_expected.to be_blank }
      its(:file_size) { is_expected.to be_blank }
      its(:checksum) { is_expected.to be_blank }
      its(:audio_codec) { is_expected.to be_blank }
      its(:video_codec) { is_expected.to be_blank }
      its(:audio_bitrate) { is_expected.to be_blank }
      its(:video_bitrate) { is_expected.to be_blank }
    end

    context 'output' do
      subject { created_job.output }

      it { is_expected.to be_blank }
    end
  end

  describe "#find" do
    context "a running encode" do
      subject { running_job }

      it 'returns an ActiveEncode::Base object' do
        expect(subject.class).to be ActiveEncode::Base
      end
      its(:id) { is_expected.to eq 'running-id' }
      it { is_expected.to be_running }
      its(:percent_complete) { is_expected.to be > 0 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_kind_of Time }
      its(:updated_at) { is_expected.to be > subject.created_at }
    end

    context "a cancelled encode" do
      subject { canceled_job }

      it 'returns an ActiveEncode::Base object' do
        expect(subject.class).to be ActiveEncode::Base
      end
      its(:id) { is_expected.to eq 'cancelled-id' }
      it { is_expected.to be_cancelled }
      its(:percent_complete) { is_expected.to be > 0 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_kind_of Time }
      its(:updated_at) { is_expected.to be >= subject.created_at }
      # its(:tech_metadata) { is_expected.to be_empty }
    end

    context "a completed encode" do
      subject { completed_job }

      it 'returns an ActiveEncode::Base object' do
        expect(subject.class).to be ActiveEncode::Base
      end
      its(:id) { is_expected.to eq 'completed-id' }
      it { is_expected.to be_completed }
      its(:output) { is_expected.to eq completed_output }
      its(:percent_complete) { is_expected.to eq 100 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_kind_of Time }
      its(:updated_at) { is_expected.to be > subject.created_at }
      # its(:tech_metadata) { is_expected.to include completed_tech_metadata }
    end

    context "a failed encode" do
      subject { failed_job }

      it 'returns an ActiveEncode::Base object' do
        expect(subject.class).to be ActiveEncode::Base
      end
      its(:id) { is_expected.to eq 'failed-id' }
      it { is_expected.to be_failed }
      its(:percent_complete) { is_expected.to be > 0 }
      its(:errors) { is_expected.not_to be_empty }
      its(:created_at) { is_expected.to be_kind_of Time }
      its(:updated_at) { is_expected.to be > subject.created_at }
      # its(:tech_metadata) { is_expected.to include failed_tech_metadata }
    end
  end

  describe "#cancel!" do
    subject { cancelling_job.cancel! }

    it 'returns an ActiveEncode::Base object' do
      expect(subject.class).to be ActiveEncode::Base
    end
    its(:id) { is_expected.to eq 'cancelled-id' }
    it { is_expected.to be_cancelled }
    its(:percent_complete) { is_expected.to be > 0 }
    its(:errors) { is_expected.to be_empty }
    its(:created_at) { is_expected.to be_kind_of Time }
    its(:updated_at) { is_expected.to be >= subject.created_at }
    # its(:tech_metadata) { is_expected.to be_empty }
  end

  describe "reload" do
    subject { running_job.reload }

    it 'returns an ActiveEncode::Base object' do
      expect(subject.class).to be ActiveEncode::Base
    end
    its(:id) { is_expected.to eq 'running-id' }
    it { is_expected.to be_running }
    its(:percent_complete) { is_expected.to be > 0 }
    its(:errors) { is_expected.to be_empty }
    its(:created_at) { is_expected.to be_kind_of Time }
    its(:updated_at) { is_expected.to be > subject.created_at }
  end
end
