# frozen_string_literal: true
module ActiveEncode
  module EngineAdapters
    module MediaConvertOutput
      class << self
        AUDIO_SETTINGS = {
          "AAC" => :aac_settings,
          "AC3" => :ac3_settings,
          "AIFF" => :aiff_settings,
          "EAC3_ATMOS" => :eac_3_atmos_settings,
          "EAC3" => :eac_3_settings,
          "MP2" => :mp_2_settings,
          "MP3" => :mp_3_settings,
          "OPUS" => :opus_settings,
          "VORBIS" => :vorbis_settings,
          "WAV" => :wav_settings
        }.freeze

        VIDEO_SETTINGS = {
          "AV1" => :av_1_settings,
          "AVC_INTRA" => :avc_intra_settings,
          "FRAME_CAPTURE" => :frame_capture_settings,
          "H_264" => :h264_settings,
          "H_265" => :h265_settings,
          "MPEG2" => :mpeg_2_settings,
          "PRORES" => :prores_settings,
          "VC3" => :vc_3_settings,
          "VP8" => :vp_8_settings,
          "VP9" => :vp_9_settings,
          "XAVC" => :xavc_settings
        }.freeze

        # @param output_url [String] url, expected to be `s3://`
        # @param output_settings [Aws::MediaConvert::Types::Output]
        # @param output_detail_settings [Aws::MediaConvert::Types::OutputDetail]
        def tech_metadata_from_settings(output_url:, output_settings:, output_detail_settings:)
          {
            width: output_detail_settings.video_details&.width_in_px,
            height: output_detail_settings.video_details&.height_in_px,
            frame_rate: extract_video_frame_rate(output_settings),
            duration: output_detail_settings.duration_in_ms,
            audio_codec: extract_audio_codec(output_settings),
            video_codec: extract_video_codec(output_settings),
            audio_bitrate: extract_audio_bitrate(output_settings),
            video_bitrate: extract_video_bitrate(output_settings),
            url: output_url,
            label: (output_url ? File.basename(output_url) : output_settings.name_modifier),
            suffix: output_settings.name_modifier
          }
        end

        def tech_metadata_from_logged(settings, logged_output)
          url = logged_output.dig('outputFilePaths', 0)
          {
            width: logged_output.dig('videoDetails', 'widthInPx'),
            height: logged_output.dig('videoDetails', 'heightInPx'),
            frame_rate: extract_video_frame_rate(settings),
            duration: logged_output['durationInMs'],
            audio_codec: extract_audio_codec(settings),
            video_codec: extract_video_codec(settings),
            audio_bitrate: extract_audio_bitrate(settings),
            video_bitrate: extract_video_bitrate(settings),
            url: url,
            label: File.basename(url),
            suffix: settings.name_modifier
          }
        end

        # constructs an `s3:` output URL  from the MediaConvert job params, the same
        # way MediaConvert will.
        #
        # @example
        #   construct_output_filename(
        #     destination: "s3://bucket/base_name",
        #     original_filename: "foo.mp3",
        #     name_modifier: "-1080",
        #     suffix: "m3u8")
        #   # =>  "s3://bucket/base_name-1080.m3u8"
        #
        # @example
        #   construct_output_filename(
        #     destination: "s3://bucket/directory_end_in_slash/",
        #     original_filename: "original-filename.mp3",
        #     name_modifier: "-1080",
        #     suffix: "m3u8")
        #   # =>  "s3://bucket/directory_end_in_slash/original_filename-1080.m3u8"
        #
        # @example
        #   construct_output_filename(
        #     destination: "s3://bucket/directory_end_in_slash/",
        #     original_filename: "original-filename.mp3",
        #     name_modifier: nil,
        #     suffix: "m3u8")
        #   # =>  "s3://bucket/directory_end_in_slash/original_filename.m3u8"
        def construct_output_url(destination:, file_input_url:, name_modifier:, file_suffix:)
          output = destination

          # MediaConvert operates such that if you give a destination ending in '/',
          # it'll use the original file name as part of output url.
          if output.end_with?('/')
            # ".*" on the end will strip extension off
            output += File.basename(file_input_url, '.*')
          end

          output += name_modifier if name_modifier

          output += "." + file_suffix

          output
        end

        def extract_audio_codec(settings)
          settings.audio_descriptions&.first&.codec_settings&.codec
        end

        def extract_audio_codec_settings(settings)
          codec = extract_audio_codec(settings)
          return nil if codec.nil?

          codec_key = AUDIO_SETTINGS[codec]
          settings.audio_descriptions.first.codec_settings[codec_key]
        end

        def extract_video_codec(settings)
          settings.video_description&.codec_settings&.codec
        end

        def extract_video_codec_settings(settings)
          codec = extract_video_codec(settings)
          return nil if codec.nil?

          codec_key = VIDEO_SETTINGS[codec]
          settings.video_description.codec_settings[codec_key]
        end

        def extract_audio_bitrate(settings)
          codec_settings = extract_audio_codec_settings(settings)
          return nil if codec_settings.nil?
          try(codec_settings, :bitrate)
        end

        def extract_video_bitrate(settings)
          codec_settings = extract_video_codec_settings(settings)
          return nil if codec_settings.nil?
          try(codec_settings, :bitrate) || try(codec_settings, :max_bitrate)
        end

        def extract_video_frame_rate(settings)
          codec_settings = extract_video_codec_settings(settings)
          return nil if codec_settings.nil?
          (codec_settings.framerate_numerator.to_f / codec_settings.framerate_denominator.to_f).round(2)
        rescue
          nil
        end

        private

        def try(struct, key)
          struct[key]
        rescue
          nil
        end
      end
    end
  end
end
