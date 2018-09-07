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
    prepare_files_and_process "running-id", true
  end
  let(:canceled_job) { ActiveEncode::Base.find('cancelled-id') }
  let(:cancelling_job) { ActiveEncode::Base.find('running-id')}
  let(:completed_job) do
    prepare_files_and_process "completed-id", false
  end
  let(:failed_job) { ActiveEncode::Base.find('failed-id') }
  let(:completed_tech_metadata) { { } }
  let(:completed_output) { { } }
  let(:failed_tech_metadata) { { } }

  it_behaves_like "an ActiveEncode::EngineAdapter"

  # Precreate ffmpeg output directory and files
  def prepare_files_and_process id, running
    FileUtils.copy_entry "spec/fixtures/ffmpeg/#{id}", "#{work_dir}/#{id}"

    # Simulate that progress is modified later than other files
    sleep 0.1
    FileUtils.touch "#{work_dir}/#{id}/progress"

    allow(Process).to receive(:getpgid).and_return running
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
