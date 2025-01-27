# frozen_string_literal: true
require 'active_support'

module ActiveEncode
  module TechnicalMetadata
    extend ActiveSupport::Concern

    included do
      attr_accessor :width
      attr_accessor :height
      attr_accessor :frame_rate

      # In milliseconds
      attr_accessor :duration

      # In bytes
      attr_accessor :file_size

      attr_accessor :checksum

      attr_accessor :audio_codec
      attr_accessor :video_codec
      attr_accessor :audio_bitrate
      attr_accessor :video_bitrate

      # Array of hashes
      attr_accessor :subtitles
      attr_accessor :format
      attr_accessor :language
    end

    def assign_tech_metadata(metadata)
      [:width, :height, :frame_rate, :duration, :file_size, :checksum,
       :audio_codec, :video_codec, :audio_bitrate, :video_bitrate, :subtitles,
       :format, :language].each do |field|
        send("#{field}=", metadata[field]) if metadata.key?(field)
      end
    end
  end
end
