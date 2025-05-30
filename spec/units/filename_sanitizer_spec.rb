# frozen_string_literal: true
require 'spec_helper'
require 'addressable'

describe ActiveEncode::FilenameSanitizer do
  describe '#sanitize_uri' do
    it 'removes file scheme' do
      uri = "file:///path/to/file"
      expect(ActiveEncode.sanitize_uri(uri)).to eq "/path/to/file"
    end
    it 'does nothing for http(s) uris' do
      uri = "https://www.googleapis.com/drive/v3/files/1WkWJ12WecI9hX-PmEbuKDGLPK_mN3kYP?alt=media"
      expect(ActiveEncode.sanitize_uri(uri)).to eq uri
    end
    context 's3' do
      it 'relativizes s3 uris' do
        uri = "s3://mybucket/guitar.mp4"
        expect(ActiveEncode.sanitize_uri(uri)).to eq "/guitar.mp4"
      end
      it 'handles capitalized buckets' do
        uri = "s3://MYBucket/guitar.mp4"
        expect(ActiveEncode.sanitize_uri(uri)).to eq "/guitar.mp4"
      end
    end
  end

  describe "#sanitize_base" do
    it 'handles percent encoded spaces' do
      uri = "file:///path%20to%20file.mov"
      expect(ActiveEncode.sanitize_base(uri)).to eq "path_to_file"
    end
  end
end
