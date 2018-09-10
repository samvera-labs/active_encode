require 'spec_helper'
require 'shared_specs/engine_adapter_specs'

describe ActiveEncode::EngineAdapters::FfmpegAdapter do
  around(:example) do |example|
    ActiveEncode::Base.engine_adapter = :ffmpeg

    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end

    ActiveEncode::Base.engine_adapter = :test
  end

  let!(:work_dir) { stub_const "ActiveEncode::EngineAdapters::FfmpegAdapter::WORK_DIR", @dir }
  let(:file) { "file://#{File.absolute_path "spec/fixtures/Bars_512kb.mp4"}" }
  let(:created_job) { ActiveEncode::Base.create(file) }
  let(:running_job) do
    allow(Process).to receive(:getpgid).and_return 8888
    find_encode "running-id"
  end
  let(:canceled_job) do
    find_encode 'cancelled-id'
  end
  let(:cancelling_job) do
    allow(Process).to receive(:kill).and_return(nil)
    find_encode 'running-id'
  end
  let(:completed_job) { find_encode "completed-id" }
  let(:failed_job) { find_encode 'failed-id' }
  let(:completed_tech_metadata) { {:audio_bitrate => 171030,
    :audio_codec => 0,
    :duration => 6.315,
    :file_size => 199160,
    :frame_rate => 23.719,
    :height => 110.0,
    :id => "99999",
    :url => "N/A",
    :video_bitrate => 74477,
    :video_codec => 0,
    :width => 200.0
  } }
  let(:completed_output) { [{ id: "99999" }] }
  let(:failed_tech_metadata) { { } }

  it_behaves_like "an ActiveEncode::EngineAdapter"

  def find_encode id
    # Precreate ffmpeg output directory and files
    FileUtils.copy_entry "spec/fixtures/ffmpeg/#{id}", "#{work_dir}/#{id}"

    # Simulate that progress is modified later than other files
    sleep 0.1
    FileUtils.touch "#{work_dir}/#{id}/progress"

    # # Stub out system calls
    # allow(described_class).to receive(:`).and_return(1234)

    ActiveEncode::Base.find(id)
  end

  describe "#create" do
    subject { created_job }

    it "creates a directory whose name is the encode id" do
      expect(File).to exist("#{work_dir}/#{subject.id}")
    end

    it "has the input technical metadata in a file" do
      expect(File.read("#{work_dir}/#{subject.id}/input_metadata")).not_to be_empty
    end

    it "has the pid in a file" do
      expect(File.read("#{work_dir}/#{subject.id}/pid")).not_to be_empty
    end
  end

  describe "#find" do
    subject { running_job }

    it "has a progress file" do
      expect(File).to exist("#{work_dir}/#{subject.id}/progress")
    end
  end

  describe "#cancel!" do
    subject { running_job }

    it "stops a running process" do
      expect(Process).to receive(:kill).with('SIGTERM', running_job.input.id.to_i)
      running_job.cancel!
    end
  end
end
