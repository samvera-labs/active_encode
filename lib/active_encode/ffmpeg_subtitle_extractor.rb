# frozen_string_literal: true
module ActiveEncode
  module FfmpegSubtitleExtractor
    require 'open3'
    require 'json'

    WORK_DIR = ENV["ENCODE_WORK_DIR"] || "encodes"
    FFMPEG_PATH = ENV["FFMPEG_PATH"] || "ffmpeg"
    FFPROBE_PATH = ENV["FFPROBE_PATH"] || "ffprobe"

    def extract_captions(input_url, id = nil, encode = nil)
      raise "ID value or Encode record missing" unless id.present? || encode.present?
      id = encode.id if encode.present?

      FileUtils.mkdir_p working_path("", id)
      FileUtils.mkdir_p working_path("supplemental_files", id)

      path = sanitize_filepath(input_url)
      ffprobe_metadata = ffprobe_result(path)
      count = subtitle_count(ffprobe_metadata)
      return if count.zero?

      sanitized_filename = ActiveEncode.sanitize_base path
      command = ffmpeg_command(path) + caption_extraction_options(sanitized_filename, count, id)

      _stdout, stderr, status = Open3.capture3(*command)
      raise "Extraction failed: #{stderr}" unless status.success?

      metadata = []
      (0..count - 1).each_with_index do |_s, i|
        metadata += [tech_metadata(working_path("supplemental_files/#{sanitized_filename}-caption#{i}.vtt", id), ffprobe_metadata, i, encode)]
      end

      # TODO: Add output information directly to encode if encode is present

      metadata
    end

    def caption_extraction_options(filename, count, id)
      opts = []
      (0..count - 1).each do |i|
        subtitle_filename = "supplemental_files/#{filename}-caption#{i}.vtt"
        opts += [
          "-map", "0:s:#{i}",
          "-c:s", "webvtt",
          working_path(subtitle_filename, id)
        ]
      end

      opts
    end

    private

    def ffmpeg_command(path)
      [
        FFMPEG_PATH, '-y',
        '-loglevel', 'level+error',
        '-i', path,
        "-max_muxing_queue_size", "1024"
      ]
    end

    def ffprobe_command(path)
      [
        FFPROBE_PATH,
        '-v', 'error',
        '-select_streams', 's',
        '-show_entries', 'stream=index:stream_tags=language,title,handler_name',
        '-of', 'json',
        path
      ]
    end

    def ffprobe_result(path)
      stdout, stderr, status = Open3.capture3(*ffprobe_command(path))
      raise "ffprobe failed: #{stderr}" unless status.success?

      JSON.parse(stdout).deep_symbolize_keys
    end

    def sanitize_filepath(input_url)
      case input_url
      when /^file\:\/\/\//
        input_url = Addressable::URI.unencode(input_url)
        ActiveEncode.sanitize_input(input_url)
      when /^s3\:\/\//
        require 'file_locator'

        s3_object = FileLocator::S3File.new(input_url).object
        URI.parse(s3_object.presigned_url(:get))
      when /^https?\:\/\//
        URI.parse(input_url)
      end
    end

    def subtitle_count(metadata)
      metadata[:streams]&.size || 0
    end

    def tech_metadata(extracted_path, probe_result, index, encode = nil)
      tags = probe_result[:streams][index][:tags]
      {
        url: "file://#{extracted_path}",
        id: encode.present? ? "#{encode.input.id}-#{File.basename(extracted_path)}" : File.basename(extracted_path),
        created_at: encode.present? ? encode.created_at : File.mtime(extracted_path),
        updated_at: File.mtime(extracted_path),
        label: tags[:title] || tags[:handler_name],
        language: tags[:language],
        format: 'vtt'
      }
    end

    def working_path(path, id)
      File.join(WORK_DIR, id, path)
    end
  end
end
