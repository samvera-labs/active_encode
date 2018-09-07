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
    prepare_files "running-id"
  end
  let(:canceled_job) { ActiveEncode::Base.find('cancelled-id') }
  let(:cancelling_job) { ActiveEncode::Base.find('running-id')}
  let(:completed_job) do
    prepare_files "completed-id"
  end
  let(:failed_job) { ActiveEncode::Base.find('failed-id') }
  # let(:completed_tech_metadata) { [{ audio_bitrate: 72000, audio_codec: 0,
  #   created_at: "2018-09-07T15:23:39.558-04:00", duration: 6.336,
  #   file_size: 125403, frame_rate: 24.0,
  #   id: "99999", label: "low",
  #   :video_bitrate => 79302, :video_codec => 0, height: 110.0, :width => 200.0}] }

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

  # Precreate ffmpeg output directory and files
  def prepare_files id
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

  # describe "#find" do
  #   subject { running_job }
  #
  #   it "creates a progress file" do
  #     expect(File).to exist("#{work_dir}/#{subject.id}/progress.out")
  #   end
  # end
end
