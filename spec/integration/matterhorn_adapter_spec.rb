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

  before do
    #Stub out all Matterhorn interactions
    allow(Rubyhorn).to receive(:client).and_return(double("Rubyhorn::MatterhornClient"))
    allow(Rubyhorn.client).to receive(:addMediaPackageWithUrl).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/create_response.xml')))
  end

  let (:file) { "file://#{File.absolute_path('spec/fixtures/Bars_512kb.mp4')}" }

  describe "#create" do
    subject { ActiveEncode::Base.create(file) }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.not_to be_empty }
    it { is_expected.to be_running }
    its(:output) { is_expected.to be_empty }
    its(:options) { is_expected.to include(preset: 'full') }
    its(:current_operations) { is_expected.to be_empty }
    its(:percent_complete) { is_expected.to eq 0 }
    its(:errors) { is_expected.to be_empty }
    its(:tech_metadata) { is_expected.to be_empty }
  end

  describe "#find" do
    context "a running encode" do
      before do
        allow(Rubyhorn.client).to receive(:instance_xml).with('running-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/running_response.xml')))
      end

      subject { ActiveEncode::Base.find('running-id') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'running-id' }
      it { is_expected.to be_running }
      its(:output) { is_expected.to be_empty }
      its(:options) { is_expected.to include(preset: 'full') }
      its(:current_operations) { is_expected.to include("Hold for workflow selection") }
      its(:percent_complete) { is_expected.to eq 0.43478260869565216 }  
      its(:errors) { is_expected.to be_empty }
      its(:tech_metadata) { is_expected.to be_empty }
    end
    context "a cancelled encode" do
      before do
        allow(Rubyhorn.client).to receive(:instance_xml).with('cancelled-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
      end

      subject { ActiveEncode::Base.find('cancelled-id') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'cancelled-id' }
      it { is_expected.to be_cancelled }
      its(:options) { is_expected.to include(preset: 'full') }
      its(:current_operations) { is_expected.to include("Tagging dublin core catalogs for publishing") }
      its(:percent_complete) { is_expected.to eq 1.7391304347826086 }  
      its(:errors) { is_expected.to be_empty }
      its(:tech_metadata) { is_expected.to be_empty }
    end
    context "a completed encode" do
      before do
        allow(Rubyhorn.client).to receive(:instance_xml).with('completed-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/completed_response.xml')))
      end
      let(:completed_output) { [{:id => "track-7", :mime_type => "video/mp4", :checksum => "77de9765545ef63d2c21f7557ead6176", :duration => "6337", :audio_codec => "AAC", :audio_channels => "2", :audio_bitrate => "76502.0", :video_codec => "AVC", :video_bitrate => "2000000.0", :video_framerate => "30.0", :width => "1308", :height => "720", :url => "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/b09c765f-b64e-4725-a863-736af66b688c/videoshort.mp4", :label => "quality-high"}, {:id => "track-8", :mime_type => "video/mp4", :checksum => "10e13cf51bf8a973011eec6a17ea47ff", :duration => "6337", :audio_codec => "AAC", :audio_channels => "2", :audio_bitrate => "76502.0", :video_codec => "AVC", :video_bitrate => "500000.0", :video_framerate => "30.0", :width => "654", :height => "360", :url => "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/8d5cd8a9-ad0e-484a-96f0-05e26a84a8f0/videoshort.mp4", :label => "quality-low"}, {:id => "track-9", :mime_type => "video/mp4", :checksum => "f2b16a2606dc76cb53c7017f0e166204", :duration => "6337", :audio_codec => "AAC", :audio_channels => "2", :audio_bitrate => "76502.0", :video_codec => "AVC", :video_bitrate => "1000000.0", :video_framerate => "30.0", :width => "872", :height => "480", :url => "file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams/f564d9de-9c35-4b74-95f0-f3013f32cc1a/0f81d426-0e26-4496-8f58-c675c86e6f4e/videoshort.mp4", :label => "quality-medium"}] }

      subject { ActiveEncode::Base.find('completed-id') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'completed-id' }
      it { is_expected.to be_completed }
      its(:output) { is_expected.to eq completed_output }
      its(:options) { is_expected.to include(preset: 'avalon') }
      its(:current_operations) { is_expected.to include("Cleaning up") }
      its(:percent_complete) { is_expected.to eq 100 }
      its(:errors) { is_expected.to be_empty }
      its(:tech_metadata) { is_expected.to be_empty }
    end
    context "a failed encode" do
      before do
        allow(Rubyhorn.client).to receive(:instance_xml).with('failed-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/failed_response.xml')))
      end
      let(:failed_tech_metadata) {{mime_type: "video/mp4", checksum: "7ae24368ccb7a6c6422a14ff73f33c9a", duration: "6314", audio_codec: "AAC", audio_channels: "2", audio_bitrate: "171030.0", video_codec: "AVC", video_bitrate: "74477.0", video_framerate: "23.719", width: "200", height: "110"}}
      let(:failed_errors) { "org.opencastproject.workflow.api.WorkflowOperationException: org.opencastproject.workflow.api.WorkflowOperationException: One of the encoding jobs did not complete successfully" }

      subject { ActiveEncode::Base.find('failed-id') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'failed-id' }
      it { is_expected.to be_failed }
      its(:options) { is_expected.to include(preset: 'error') }
      its(:current_operations) { is_expected.to include("Cleaning up after failure") }
      its(:percent_complete) { is_expected.to eq 56.666666666666664 }
      its(:errors) { is_expected.to include failed_errors }
      its(:tech_metadata) { is_expected.to include failed_tech_metadata }
    end
  end

  describe "#cancel!" do
    before do
      allow(Rubyhorn.client).to receive(:stop).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
    end
    let(:encode) { ActiveEncode::Base.create(file) }
    subject { encode.cancel! }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq 'cancelled-id' }
    it { is_expected.to be_cancelled }
  end

  describe "#purge!" do
    context "when encode is running" do
      before do
        allow(Rubyhorn.client).to receive(:stop).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/stop_running_response.xml')))
        allow(Rubyhorn.client).to receive(:delete_track).and_return('http://localhost:8080/services/job/1234.xml')
        allow(Rubyhorn.client).to receive(:get).with('/services/job/1234.xml').and_return(File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'))
      end
      let(:encode) { ActiveEncode::Base.create(file) }
      subject { encode.purge! }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'stopped-running-id' }
      it { is_expected.to be_cancelled }
      its(:output) { is_expected.to be_empty }
    end

    context "when encode is cancelled" do
      before do
        allow(Rubyhorn.client).to receive(:stop).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
#        allow(Rubyhorn.client).to receive(:get_stopped_workflow).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/cancelled_response.xml')))
      end
      let(:encode) { ActiveEncode::Base.create(file).cancel! }
      subject { encode.purge! }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'cancelled-id' }
      it { is_expected.to be_cancelled }
      its(:output) { is_expected.to be_empty }
    end 
    context "when encode is completed" do
      before do
        allow(Rubyhorn.client).to receive(:stop).and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/stop_completed_response.xml')))
        allow(Rubyhorn.client).to receive(:delete_track).and_return('http://localhost:8080/services/job/1234.xml')
        allow(Rubyhorn.client).to receive(:get).with('/services/job/1234.xml').and_return(File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'))
      end
      let(:encode) { ActiveEncode::Base.create(file).cancel! }
      subject { encode.purge! }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq 'stop-completed-id' }
      it { is_expected.to be_cancelled }
      its(:output) { is_expected.to be_empty }
    end
  end

  describe "reload" do
    before do
      expect(Rubyhorn.client).to receive(:instance_xml).twice.with('running-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/running_response.xml')))
    end

    subject { ActiveEncode::Base.find('running-id').reload }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq 'running-id' }
    it { is_expected.to be_running }
    its(:output) { is_expected.to be_empty }
    its(:options) { is_expected.to include(preset: 'full') }
    its(:current_operations) { is_expected.to include("Hold for workflow selection") }
    its(:percent_complete) { is_expected.to eq 0.43478260869565216 }  
    its(:errors) { is_expected.to be_empty }
    its(:tech_metadata) { is_expected.to be_empty }
  end

  describe "remove_output" do
    before do
      allow(Rubyhorn.client).to receive(:instance_xml).with('completed-id').and_return(Rubyhorn::Workflow.from_xml(File.open('spec/fixtures/matterhorn/completed_response.xml')))
      allow(Rubyhorn.client).to receive(:delete_track).and_return('http://localhost:8080/services/job/1234.xml')
      allow(Rubyhorn.client).to receive(:get).with('/services/job/1234.xml').and_return(File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'), File.open('spec/fixtures/matterhorn/delete_track_response.xml'))
    end
    let(:encode) { ActiveEncode::Base.find('completed-id') }
    subject { encode.remove_output! 'track-7' }
    it { is_expected.to be_a Hash }
    it 'should remove the output' do
      encode.remove_output!('track-7')
      expect(ActiveEncode::Base.find(encode.id).output.find {|o| o[:id] == 'track-7'}).to be_nil
    end
  end
end
