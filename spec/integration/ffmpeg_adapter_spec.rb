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
  let(:file) { "file://#{File.absolute_path "spec/fixtures/fireworks.mp4"}" }
  let(:created_job) do
    ActiveEncode::Base.create(file, { outputs: [{ label: "low", ffmpeg_opt: "-s 640x480" }, { label: "high", ffmpeg_opt: "-s 1280x720" }] })
  end
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
    :audio_codec => 'mp4a-40-2',
    :duration => 6.315,
    :file_size => 199160,
    :frame_rate => 23.719,
    :height => 110.0,
    :id => "99999",
    :url => "/home/pdinh/Downloads/videoshort.mp4",
    :video_bitrate => 74477,
    :video_codec => 'avc1',
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
    FileUtils.touch Dir.glob("#{work_dir}/#{id}/*.mp4")

    # # Stub out system calls
    allow_any_instance_of(ActiveEncode::EngineAdapters::FfmpegAdapter).to receive(:`).and_return(1234)

    ActiveEncode::Base.find(id)
  end

  describe "#create" do
    subject { created_job }

    it "creates a directory whose name is the encode id" do
      expect(File).to exist("#{work_dir}/#{subject.id}")
    end

    context "input file exists" do
      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{subject.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{subject.id}/pid")).not_to be_empty
      end
    end

    context "input file doesn't exist" do
      let(:missing_file) { "file:///a_bogus_file.mp4" }
      let(:missing_job) { ActiveEncode::Base.create(missing_file, { outputs: [{ label: "low", ffmpeg_opt: "-s 640x480" }]}) }

      it "returns the encode with correct error" do
        expect(missing_job.errors).to include("#{missing_file} does not exist or is not accessible")
        expect(missing_job.percent_complete).to be 1
      end
    end

    context "input file is not media" do
      let(:nonmedia_file) { "file://#{File.absolute_path "spec/integration/ffmpeg_adapter_spec.rb"}" }
      let(:nonmedia_job) { ActiveEncode::Base.create(nonmedia_file, { outputs: [{ label: "low", ffmpeg_opt: "-s 640x480" }]}) }

      it "returns the encode with correct error" do
        expect(nonmedia_job.errors).to include("Error inspecting input: #{nonmedia_file}")
        expect(nonmedia_job.percent_complete).to be 1
      end
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
