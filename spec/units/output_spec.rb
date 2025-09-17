# frozen_string_literal: true
require 'spec_helper'

describe ActiveEncode::Output do
  subject { described_class.new }

  describe 'attributes' do
    it { is_expected.to respond_to(:id, :url, :label) }
    it { is_expected.to respond_to(:state, :errors, :created_at, :updated_at) }
    it {
      is_expected.to respond_to(:width, :height, :frame_rate, :checksum,
                                :audio_codec, :video_codec, :audio_bitrate, :video_bitrate,
                                :subtitles, :format, :language)
    }
    it { is_expected.to respond_to(:tech_metadata) }
  end

  describe '#valid?' do
    let(:valid_output) do
      described_class.new.tap do |obj|
        obj.id = "1"
        obj.url = "file:///tmp/video.mp4"
        obj.label = "HD"
        obj.created_at = Time.now.utc
        obj.updated_at = Time.now.utc
      end
    end

    it 'returns true when conditions met' do
      expect(valid_output).to be_valid
    end

    it 'returns false when conditions not met' do
      expect(valid_output.tap { |obj| obj.id = nil }).not_to be_valid
      expect(valid_output.tap { |obj| obj.url = nil }).not_to be_valid
      expect(valid_output.tap { |obj| obj.label = nil }).not_to be_valid
      expect(valid_output.tap { |obj| obj.created_at = nil }).not_to be_valid
      expect(valid_output.tap { |obj| obj.created_at = "today" }).not_to be_valid
      expect(valid_output.tap { |obj| obj.updated_at = nil }).not_to be_valid
      expect(valid_output.tap { |obj| obj.updated_at = "today" }).not_to be_valid
      expect(valid_output.tap { |obj| obj.created_at = Time.now.utc }).not_to be_valid
    end
  end
end
