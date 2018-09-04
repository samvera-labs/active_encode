require 'spec_helper'
require 'rubyhorn'
require 'shared_specs/engine_adapter_specs'

describe ActiveEncode::EngineAdapters::MatterhornAdapter do
  before(:all) do
    Rubyhorn.init(environment: 'test')
    ActiveEncode::Base.engine_adapter = :matterhorn
  end
  after(:all) do
    ActiveEncode::Base.engine_adapter = :test
  end

  before do
    # Stub out all Matterhorn interactions
    allow(Rubyhorn).to receive(:client).and_return(double("Rubyhorn::MatterhornClient"))
    allow(Rubyhorn.client).to receive(:addMediaPackageWithUrl).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/create_response.xml')))
    allow(Rubyhorn.client).to receive(:instance_xml).with('running-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/running_response.xml')))
    allow(Rubyhorn.client).to receive(:instance_xml).with('cancelled-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
    allow(Rubyhorn.client).to receive(:instance_xml).with('completed-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/completed_response.xml')))
    allow(Rubyhorn.client).to receive(:instance_xml).with('failed-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/failed_response.xml')))
    allow(Rubyhorn.client).to receive(:stop).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
  end

  let(:file) { "file://#{File.absolute_path('spec/fixtures/Bars_512kb.mp4')}" }
  let(:created_job) { ActiveEncode::Base.create(file) }
  let(:running_job) { ActiveEncode::Base.find('running-id') }
  let(:canceled_job) { ActiveEncode::Base.find('cancelled-id') }
  let(:cancelling_job) { ActiveEncode::Base.find('running-id')}
  let(:completed_job) { ActiveEncode::Base.find('completed-id') }
  let(:failed_job) { ActiveEncode::Base.find('failed-id') }

  let(:completed_output) { [{ id: "track-7", mime_type: "video/mp4", checksum: "77de9765545ef63d2c21f7557ead6176", duration: "6337", audio_codec: "AAC", audio_channels: "2", audio_bitrate: "76502.0", video_codec: "AVC", video_bitrate: "2000000.0", video_framerate: "30.0", width: "1308", height: "720", url: "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/b09c765f-b64e-4725-a863-736af66b688c/videoshort.mp4", label: "quality-high" }, { id: "track-8", mime_type: "video/mp4", checksum: "10e13cf51bf8a973011eec6a17ea47ff", duration: "6337", audio_codec: "AAC", audio_channels: "2", audio_bitrate: "76502.0", video_codec: "AVC", video_bitrate: "500000.0", video_framerate: "30.0", width: "654", height: "360", url: "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/8d5cd8a9-ad0e-484a-96f0-05e26a84a8f0/videoshort.mp4", label: "quality-low" }, { id: "track-9", mime_type: "video/mp4", checksum: "f2b16a2606dc76cb53c7017f0e166204", duration: "6337", audio_codec: "AAC", audio_channels: "2", audio_bitrate: "76502.0", video_codec: "AVC", video_bitrate: "1000000.0", video_framerate: "30.0", width: "872", height: "480", url: "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/0f81d426-0e26-4496-8f58-c675c86e6f4e/videoshort.mp4", label: "quality-medium" }] }
  let(:completed_tech_metadata) { { } }
  let(:failed_tech_metadata) { { mime_type: "video/mp4", checksum: "7ae24368ccb7a6c6422a14ff73f33c9a", duration: "6314", audio_codec: "AAC", audio_channels: "2", audio_bitrate: "171030.0", video_codec: "AVC", video_bitrate: "74477.0", video_framerate: "23.719", width: "200", height: "110" } }
  let(:failed_errors) { "org.opencastproject.workflow.api.WorkflowOperationException: org.opencastproject.workflow.api.WorkflowOperationException: One of the encoding jobs did not complete successfully" }

  # Enforce generic behavior
  it_behaves_like "an ActiveEncode::EngineAdapter"

  describe "#create" do
    subject { created_job }

    its(:output) { is_expected.to be_empty }
    its(:options) { is_expected.to include(preset: 'full') }
  end

  describe "#find" do
    context "a running encode" do
      subject { running_job }

      its(:options) { is_expected.to include(preset: 'full') }
      its(:output) { is_expected.to be_empty }
      its(:current_operations) { is_expected.to include("Hold for workflow selection") }

      context 'input' do
        subject { running_job.input }

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
    end
    context "a cancelled encode" do
      subject { canceled_job }

      its(:options) { is_expected.to include(preset: 'full') }
      its(:current_operations) { is_expected.not_to be_empty }
      its(:current_operations) { is_expected.to include("Tagging dublin core catalogs for publishing") }
      its(:updated_at) { is_expected.to be > subject.created_at }
    end

    context "a completed encode" do
      subject { completed_job }

      its(:options) { is_expected.to include(preset: 'avalon') }
      its(:current_operations) { is_expected.to include("Cleaning up") }
    end
    context "a failed encode" do
      subject { failed_job }

      its(:options) { is_expected.to include(preset: 'error') }
      its(:current_operations) { is_expected.to include("Cleaning up after failure") }
    end
  end

  describe "#cancel!" do
    let(:encode) { ActiveEncode::Base.create(file) }
    subject { encode.cancel! }

    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq 'cancelled-id' }
    it { is_expected.to be_cancelled }
  end

  describe "reload" do
    before do
      expect(Rubyhorn.client).to receive(:instance_xml).twice.with('running-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/running_response.xml')))
    end

    subject { running_job.reload }

    its(:output) { is_expected.to be_empty }
    its(:options) { is_expected.to include(preset: 'full') }
    its(:current_operations) { is_expected.to include("Hold for workflow selection") }
    its(:percent_complete) { is_expected.to eq 0.43478260869565216 }

    context 'input' do
      subject { running_job.reload.input }

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
  end
end
