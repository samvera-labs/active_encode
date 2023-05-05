# frozen_string_literal: true
require 'rails_helper'
require 'active_encode/spec/shared_specs'

describe ActiveEncode::EngineAdapters::FfmpegAdapter do
  around do |example|
    ActiveEncode::Base.engine_adapter = :ffmpeg

    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
      Dir.foreach(dir) do |e|
        next if e == "." || e == ".."
        FileUtils.rm_rf(File.join(dir, e))
      end
    end

    ActiveEncode::Base.engine_adapter = :test
  end

  let!(:work_dir) { stub_const "ActiveEncode::EngineAdapters::FfmpegAdapter::WORK_DIR", @dir }
  let(:file) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'fireworks.mp4').to_s }
  let(:created_job) do
    ActiveEncode::Base.create(file, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: "mp4" }, { label: "high", ffmpeg_opt: "-s 1280x720", extension: "mp4" }])
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
    encode = find_encode 'running-id'
    File.write "#{work_dir}/running-id/cancelled", ""
    encode
  end
  let(:completed_job) { find_encode "completed-id" }
  let(:completed_with_warnings_job) { find_encode "completed-with-warnings-id" }
  let(:incomplete_job) { find_encode "incomplete-id" }
  let(:failed_job) { find_encode 'failed-id' }
  let(:completed_tech_metadata) do
    {
      audio_bitrate: 171_030,
      audio_codec: 'mp4a-40-2',
      duration: 6315,
      file_size: 199_160,
      frame_rate: 23.719,
      height: 110.0,
      id: "99999",
      url: "/home/pdinh/Downloads/videoshort.mp4",
      video_bitrate: 74_477,
      video_codec: 'avc1',
      width: 200.0
    }
  end
  let(:completed_output) { [{ id: "99999" }] }
  let(:failed_tech_metadata) { {} }

  it_behaves_like "an ActiveEncode::EngineAdapter"

  def find_encode(id)
    # Precreate ffmpeg output directory and files
    FileUtils.copy_entry "spec/fixtures/ffmpeg/#{id}", "#{work_dir}/#{id}"

    # Simulate that progress is modified later than other files
    sleep 0.1
    FileUtils.touch "#{work_dir}/#{id}/progress"
    FileUtils.touch Dir.glob("#{work_dir}/#{id}/*.mp4")

    # Stub out system calls
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
      let(:missing_job) { ActiveEncode::Base.create(missing_file, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }

      it "returns the encode with correct error" do
        expect(missing_job.errors).to include("#{missing_file} does not exist or is not accessible")
        expect(missing_job.percent_complete).to be 1
      end
    end

    context "input file is not media" do
      let(:nonmedia_file) { "file://" + Rails.root.join('Gemfile').to_s }
      let(:nonmedia_job) { ActiveEncode::Base.create(nonmedia_file, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }

      it "returns the encode with correct error" do
        expect(nonmedia_job.errors).to include("Error inspecting input: #{nonmedia_file}")
        expect(nonmedia_job.percent_complete).to be 1
      end
    end

    context "input file format does not match extension" do
      let(:improper_format_file) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'file_without_metadata.mp4').to_s }
      let(:improper_format_job) { ActiveEncode::Base.create(improper_format_file, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }

      it "returns the encode with correct error" do
        expect(improper_format_job.errors).to include("Error inspecting input: #{improper_format_file}")
        expect(improper_format_job.percent_complete).to be 1
      end
    end

    context "input file with missing metadata" do
      let(:file_without_metadata) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'file_without_metadata.webm').to_s }
      let!(:create_without_metadata_job) { ActiveEncode::Base.create(file_without_metadata, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_without_metadata_job) { ActiveEncode::Base.find create_without_metadata_job.id }

      it "does not have errors" do
        sleep 2
        expect(find_without_metadata_job.errors).to be_empty
      end

      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{create_without_metadata_job.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{create_without_metadata_job.id}/pid")).not_to be_empty
      end

      it "assigns the correct duration to the encode" do
        expect(create_without_metadata_job.input.duration).to eq 68_653
        expect(find_without_metadata_job.input.duration).to eq 68_653
      end

      context 'when uri encoded' do
        let(:file_without_metadata) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', 'file_without_metadata.webm').to_s) }

        it "does not have errors" do
          sleep 2
          expect(find_without_metadata_job.errors).to be_empty
        end

        it "has the input technical metadata in a file" do
          expect(File.read("#{work_dir}/#{create_without_metadata_job.id}/input_metadata")).not_to be_empty
        end

        it "has the pid in a file" do
          expect(File.read("#{work_dir}/#{create_without_metadata_job.id}/pid")).not_to be_empty
        end

        it "assigns the correct duration to the encode" do
          expect(create_without_metadata_job.input.duration).to eq 68_653
          expect(find_without_metadata_job.input.duration).to eq 68_653
        end
      end
    end

    context "input filename with spaces" do
      let(:file_with_space) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'file with space.mp4').to_s }
      let!(:create_space_job) { ActiveEncode::Base.create(file_with_space, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_space_job) { ActiveEncode::Base.find create_space_job.id }

      it "does not have errors" do
        sleep 2
        expect(find_space_job.errors).to be_empty
      end

      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{create_space_job.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{create_space_job.id}/pid")).not_to be_empty
      end

      context 'when uri encoded' do
        let(:file_with_space) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', 'file with space.mp4').to_s) }

        it "does not have errors" do
          sleep 2
          expect(find_space_job.errors).to be_empty
        end

        it "has the input technical metadata in a file" do
          expect(File.read("#{work_dir}/#{create_space_job.id}/input_metadata")).not_to be_empty
        end

        it "has the pid in a file" do
          expect(File.read("#{work_dir}/#{create_space_job.id}/pid")).not_to be_empty
        end
      end
    end

    context "input filename with single quotes" do
      let(:file_with_single_quote) { "file://" + Rails.root.join('..', 'spec', 'fixtures', "'file_with_single_quote'.mp4").to_s }
      let!(:create_single_quote_job) { ActiveEncode::Base.create(file_with_single_quote, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_single_quote_job) { ActiveEncode::Base.find create_single_quote_job.id }

      it "does not have errors" do
        sleep 2
        expect(find_single_quote_job.errors).to be_empty
      end

      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{create_single_quote_job.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{create_single_quote_job.id}/pid")).not_to be_empty
      end

      context 'when uri encoded' do
        let(:file_with_single_quote) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', "'file_with_single_quote'.mp4").to_s) }

        it "does not have errors" do
          sleep 2
          expect(find_single_quote_job.errors).to be_empty
        end

        it "has the input technical metadata in a file" do
          expect(File.read("#{work_dir}/#{create_single_quote_job.id}/input_metadata")).not_to be_empty
        end

        it "has the pid in a file" do
          expect(File.read("#{work_dir}/#{create_single_quote_job.id}/pid")).not_to be_empty
        end
      end
    end

    context "input filename with double quotes" do
      let(:file_with_double_quote) { "file://" + Rails.root.join('..', 'spec', 'fixtures', '"file_with_double_quote".mp4').to_s }
      let!(:create_double_quote_job) { ActiveEncode::Base.create(file_with_double_quote, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_double_quote_job) { ActiveEncode::Base.find create_double_quote_job.id }

      it "does not have errors" do
        sleep 2
        expect(find_double_quote_job.errors).to be_empty
      end

      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{create_double_quote_job.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{create_double_quote_job.id}/pid")).not_to be_empty
      end

      context 'when uri encoded' do
        let(:file_with_double_quote) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', '"file_with_double_quote".mp4').to_s) }

        it "does not have errors" do
          sleep 2
          expect(find_double_quote_job.errors).to be_empty
        end

        it "has the input technical metadata in a file" do
          expect(File.read("#{work_dir}/#{create_double_quote_job.id}/input_metadata")).not_to be_empty
        end

        it "has the pid in a file" do
          expect(File.read("#{work_dir}/#{create_double_quote_job.id}/pid")).not_to be_empty
        end
      end
    end

    context "input filename with other special characters" do
      let(:file_with_special_characters) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'file.with :=+%sp3c!l-ch4cts().mp4').to_s }
      let!(:create_special_characters_job) { ActiveEncode::Base.create(file_with_special_characters, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_special_characters_job) { ActiveEncode::Base.find create_special_characters_job.id }
      let(:file_with_more_special_characters) { "file://" + Rails.root.join('..', 'spec', 'fixtures', '@ወዳጅህ ማር ቢ. ሆን ጨርስ. ህ አትላሰ!@#$^^&$%&.mov').to_s }
      let!(:create_more_special_characters_job) { ActiveEncode::Base.create(file_with_more_special_characters, outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: 'mp4' }]) }
      let(:find_more_special_characters_job) { ActiveEncode::Base.find create_more_special_characters_job.id }

      it "does not have errors" do
        sleep 2
        expect(find_special_characters_job.errors).to be_empty
        expect(find_more_special_characters_job.errors).to be_empty
      end

      it "has the input technical metadata in a file" do
        expect(File.read("#{work_dir}/#{create_special_characters_job.id}/input_metadata")).not_to be_empty
        expect(File.read("#{work_dir}/#{create_more_special_characters_job.id}/input_metadata")).not_to be_empty
      end

      it "has the pid in a file" do
        expect(File.read("#{work_dir}/#{create_special_characters_job.id}/pid")).not_to be_empty
        expect(File.read("#{work_dir}/#{create_more_special_characters_job.id}/pid")).not_to be_empty
      end

      context 'when uri encoded' do
        let(:file_with_special_characters) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', 'file.with :=+%sp3c!l-ch4cts().mp4').to_s) }
        let(:file_with_more_special_characters) { Addressable::URI.encode("file://" + Rails.root.join('..', 'spec', 'fixtures', '@ወዳጅህ ማር ቢ. ሆን ጨርስ. ህ አትላሰ!@#$^^&$%&.mov').to_s) }

        it "does not have errors" do
          sleep 2
          expect(find_special_characters_job.errors).to be_empty
          expect(find_more_special_characters_job.errors).to be_empty
        end

        it "has the input technical metadata in a file" do
          expect(File.read("#{work_dir}/#{create_special_characters_job.id}/input_metadata")).not_to be_empty
          expect(File.read("#{work_dir}/#{create_more_special_characters_job.id}/input_metadata")).not_to be_empty
        end

        it "has the pid in a file" do
          expect(File.read("#{work_dir}/#{create_special_characters_job.id}/pid")).not_to be_empty
          expect(File.read("#{work_dir}/#{create_more_special_characters_job.id}/pid")).not_to be_empty
        end
      end
    end

    context 'when failed' do
      subject { created_job }

      before do
        allow_any_instance_of(Object).to receive(:`).and_raise Errno::ENOENT
      end

      it { is_expected.to be_failed }
      it { expect(subject.errors).to be_present }
    end
  end

  describe "#find" do
    subject { running_job }

    it "has a progress file" do
      expect(File).to exist("#{work_dir}/#{subject.id}/progress")
    end

    it "does not have an exit code file" do
      expect(File).not_to exist("#{work_dir}/#{subject.id}/exit_status.code")
    end

    context "completed job" do
      subject { completed_job }

      it { is_expected.to be_completed }
      it "has an exit code of 0" do
        expect(File).to exist("#{work_dir}/#{subject.id}/exit_status.code")
        expect(File.read("#{work_dir}/#{subject.id}/exit_status.code").to_i).to eq 0
      end
    end

    context "completed with warnings job" do
      subject { completed_with_warnings_job }

      it { is_expected.to be_completed }
      it "has an exit code of 0" do
        expect(File).to exist("#{work_dir}/#{subject.id}/exit_status.code")
        expect(File.read("#{work_dir}/#{subject.id}/exit_status.code").to_i).to eq 0
      end
      it "has warnings in the error log" do
        expect(File).to exist("#{work_dir}/#{subject.id}/error.log")
        expect(File.read("#{work_dir}/#{subject.id}/error.log")).not_to be_empty
      end
    end

    context "cancelled job" do
      subject { canceled_job }

      it { is_expected.to be_cancelled }
      it "has an exit code of 143" do
        expect(File).to exist("#{work_dir}/#{subject.id}/exit_status.code")
        expect(File.read("#{work_dir}/#{subject.id}/exit_status.code").to_i).to eq 143
      end
    end

    context "failed job" do
      subject { failed_job }

      it { is_expected.to be_failed }
      it "has an exit code of -22" do
        expect(File).to exist("#{work_dir}/#{subject.id}/exit_status.code")
        expect(File.read("#{work_dir}/#{subject.id}/exit_status.code").to_i).to eq(-22)
      end

      context 'with less than 100 percent completeness' do
        subject { incomplete_job }

        it { is_expected.to be_failed }
        it 'has an error' do
          expect(incomplete_job.errors).to include "Encoding has completed but the output duration is shorter than the input"
        end

        it 'succeeds with a configured completeness threshold' do
          allow(ActiveEncode::EngineAdapters::FfmpegAdapter).to receive(:completeness_threshold).and_return(95)
          expect(incomplete_job).not_to be_failed
          expect(incomplete_job.errors).to be_empty
        end
      end
    end
  end

  describe "#cancel!" do
    subject { running_job }

    it "stops a running process" do
      expect(Process).to receive(:kill).with('SIGTERM', running_job.input.id.to_i)
      running_job.cancel!
    end

    it "does not attempt to stop a non-running encode" do
      expect(Process).not_to receive(:kill).with('SIGTERM', completed_job.input.id.to_i)
      completed_job.cancel!
    end

    it "raises an error if the process can not be found" do
      expect(Process).to receive(:kill).with('SIGTERM', running_job.input.id.to_i).and_raise(Errno::ESRCH)
      expect { running_job.cancel! }.to raise_error(ActiveEncode::NotRunningError)
    end

    it "raises an error" do
      expect(Process).to receive(:kill).with('SIGTERM', running_job.input.id.to_i).and_raise(Errno::EPERM)
      expect { running_job.cancel! }.to raise_error(ActiveEncode::CancelError)
    end
  end

  describe "#remove_old_files!" do
    subject { created_job }
    # 'exit_status.code' and 'progress' seem to be hidden files so rspec does not see them.
    # That is why they are not explicitly included in the tests even though they are in the filenames list.
    # If they were not being deleted they would cause other tests to fail.
    let(:filenames) { ['input_metadata', 'error.log', 'pid', 'exit_status.code', 'progress'] }
    let(:pathnames) { filenames.each_with_index { |fn, i| filenames[i] = fn.dup.prepend("#{work_dir}/#{subject.id}/") } }

    # There was some flaky behavior with the file creation for created_job that
    # would cause tests to fail. This ensures the files are created.
    before :each do
      FileUtils.touch(pathnames)
    end

    context ":no_outputs" do
      it "deletes files created from encode process older than 2 weeks" do
        # Another measure to give files time to be created.
        sleep 1
        travel 3.weeks do
          expect { described_class.remove_old_files! }
            .to change { File.exist?(pathnames[0]) }.from(true).to(false)
            .and change { File.exist?(pathnames[1]) }.from(true).to(false)
            .and change { File.exist?(pathnames[2]) }.from(true).to(false)
            .and not_change { Dir.children("#{work_dir}/#{subject.id}/outputs").count }.from(2)
        end
      end

      it "does not delete files younger than 2 weeks" do
        sleep 1
        expect { described_class.remove_old_files! }
          .to not_change { File.exist?(pathnames[0]) }.from(true)
          .and not_change { File.exist?(pathnames[1]) }.from(true)
          .and not_change { File.exist?(pathnames[2]) }.from(true)
          .and not_change { Dir.children("#{work_dir}/#{subject.id}/outputs").count }.from(2)
      end
    end

    context ":outputs" do
      it "deletes outputs created from encode process older than 2 weeks" do
        sleep 1
        travel 3.weeks do
          expect { described_class.remove_old_files!(outputs: true) }
            .to not_change { File.exist?(pathnames[0]) }.from(true)
            .and not_change { File.exist?(pathnames[1]) }.from(true)
            .and not_change { File.exist?(pathnames[2]) }.from(true)
            .and change { Dir.exist?("#{work_dir}/#{subject.id}/outputs") }.from(true).to(false)
        end
      end

      it "does not delete outputs younger than 2 weeks" do
        sleep 1
        expect { described_class.remove_old_files!(outputs: true) }
          .to not_change { File.exist?(pathnames[0]) }.from(true)
          .and not_change { File.exist?(pathnames[1]) }.from(true)
          .and not_change { File.exist?(pathnames[2]) }.from(true)
          .and not_change { Dir.children("#{work_dir}/#{subject.id}/outputs").count }.from(2)
      end

      it "does not delete outputs directory containing files younger than 2 weeks" do
        sleep 1
        travel 3.weeks do
          allow(File).to receive(:mtime).and_call_original
          allow(File).to receive(:mtime).with("#{work_dir}/#{subject.id}/outputs/fireworks-low.mp4").and_return(DateTime.now)
          expect { described_class.remove_old_files!(outputs:true) }
            .to not_change { Dir.exist?("#{work_dir}/#{subject.id}/outputs") }.from (true)
          expect(Dir.children("#{work_dir}/#{subject.id}/outputs")).to eq(["fireworks-low.mp4"])
        end
      end
    end

    context ":all" do
      it "deletes all files and directories older than 2 weeks" do
        sleep 1
        travel 3.weeks do
          expect { described_class.remove_old_files!(all: true) }
            .to change { Dir.exist?("#{work_dir}/#{subject.id}") }.from(true).to(false)
        end
      end

      it "does not delete files and directories younger than 2 weeks" do
        sleep 1
        expect { described_class.remove_old_files!(all: true) }
          .to not_change { Dir.exist?("#{work_dir}/#{subject.id}") }.from(true)
          .and not_change { Dir.children("#{work_dir}/#{subject.id}").count }
      end

      it "does not delete directories containing files younger than 2 weeks" do
        sleep 1
        travel 3.weeks do
          allow(File).to receive(:mtime).and_call_original
          allow(File).to receive(:mtime).with("#{work_dir}/#{subject.id}/input_metadata").and_return(DateTime.now)
          expect { described_class.remove_old_files!(all:true) }
            .to not_change { Dir.exist?("#{work_dir}/#{subject.id}") }.from (true)
          expect(Dir.children("#{work_dir}/#{subject.id}")).to eq(["input_metadata"])
        end
      end
    end
  end
end
