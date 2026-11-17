# frozen_string_literal: true
require 'spec_helper'

describe ActiveEncode::FfmpegSubtitleExtractor do
  let(:captioned_video) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'file_with_embedded_captions.mp4').to_s }
  let(:video) { "file://" + Rails.root.join('..', 'spec', 'fixtures', 'fireworks.mp4').to_s }

  describe "#caption_extraction_options" do
    subject { ActiveEncode.caption_extraction_options("test.mp4", 1, "test1234") }
    let(:result) { ['-map', '0:s:0', '-c:s', 'webvtt', 'encodes/test1234/supplemental_files/test.mp4-caption0.vtt'] }

    it 'returns an array of options' do
      expect(subject).to be_an(Array)
      expect(subject).to match_array(result)
    end
  end

  describe "#extract_captions" do
    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        example.run
        Dir.foreach(dir) do |e|
          next if e == "." || e == ".."
          FileUtils.rm_rf(File.join(dir, e))
        end
      end
    end

    subject { ActiveEncode.extract_captions(captioned_video, 'test') }
    let!(:work_dir) { stub_const "ActiveEncode::FfmpegSubtitleExtractor::WORK_DIR", @dir }

    it 'returns an array of metadata' do
      expect(subject).to be_an(Array)
      expect(subject.count).to eq 2
      expect(subject).to all(be_a(Hash))
      expect(subject[0]).to include(:url, :id, :updated_at, :label, :language, :format)
      expect(subject[0][:format]).to eq "vtt"
      expect(subject[0][:label]).to eq "Test"
      expect(subject[0][:language]).to eq "eng"
    end

    it 'extracts the subtitle files' do
      file1 = File.join(@dir, 'test', 'supplemental_files', 'file_with_embedded_captions-caption0.vtt')
      file2 = File.join(@dir, 'test', 'supplemental_files', 'file_with_embedded_captions-caption1.vtt')
      expect { subject }.to change { File.exist?(file1) }.from(false).to(true)
                        .and change { File.exist?(file2) }.from(false).to(true)
    end

    it 'raises an error if id and encode are not provided' do
      expect { ActiveEncode.extract_captions(captioned_video) }.to raise_error
    end
  end
end
