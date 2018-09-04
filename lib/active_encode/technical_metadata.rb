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
    end
  end
end
