# frozen_string_literal: true
require 'fileutils'
require 'nokogiri'
require 'shellwords'
require 'file_locator'

# PassThroughAdapter accepts an input file url and a number of derivative urls in the options
# E.g. `create(input, outputs: [{ label: 'low',  url: 'file:///derivatives/low.mp4' }, { label: 'high', url: 'file:///derivatives/high.mp4' }])`
# This adapter mirrors the ffmpeg adapter but differs in a few ways:
#    1. It starts by copying the derivative files to the work directory
#    2. It runs Mediainfo on the input and output files and skips ffmpeg
#    3. All work is done in the create method so it's status is always completed or failed
module ActiveEncode
  module EngineAdapters
    class PassThroughAdapter
      WORK_DIR = ENV["ENCODE_WORK_DIR"] || "encodes" # Should read from config
      MEDIAINFO_PATH = ENV["MEDIAINFO_PATH"] || "mediainfo"
      FFMPEG_PATH = ENV["FFMPEG_PATH"] || "ffmpeg"

      def create(input_url, options = {})
        # Decode file uris for ffmpeg (mediainfo works either way)
        input_url = Addressable::URI.unencode(input_url) if input_url.starts_with? "file:///"
        input_url = ActiveEncode.sanitize_input(input_url)

        new_encode = ActiveEncode::Base.new(input_url, options)
        new_encode.id = SecureRandom.uuid
        new_encode.current_operations = []
        new_encode.output = []

        # Create a working directory that holds all output files related to the encode
        FileUtils.mkdir_p working_path("", new_encode.id)
        FileUtils.mkdir_p working_path("outputs", new_encode.id)

        # Extract technical metadata from input file
        `#{MEDIAINFO_PATH} --Output=XML --LogFile=#{working_path("input_metadata", new_encode.id)} "#{ActiveEncode.sanitize_uri(input_url)}"`
        new_encode.input = build_input new_encode
        new_encode.input.id = new_encode.id
        new_encode.created_at, new_encode.updated_at = get_times new_encode.id

        # Log error if file is empty or inaccessible
        if new_encode.input.duration.blank? && new_encode.input.file_size.blank?
          file_error(new_encode, input_url)
          return new_encode
        # If file is not empty, try copying file to generate missing metadata
        elsif new_encode.input.duration.blank? && new_encode.input.file_size.present?
          # filepath = clean_url.to_s.gsub(/\?.*/, '')
          copy_url = input_url.gsub(input_url, "#{File.basename(input_url, File.extname(input_url))}_temp#{File.extname(input_url)}")
          copy_path = working_path(copy_url, new_encode.id)

          # -map 0 sets ffmpeg to copy all available streams.
          # -c copy sets ffmpeg to copy all codecs
          # -y automatically overwrites the temp file if one already exists
          `#{FFMPEG_PATH} -loglevel level+fatal -i \"#{input_url}\" -map 0 -c copy -y \"#{copy_path}\"`

          # If ffmpeg copy fails, log error because file is either not a media file
          # or the file extension does not match the codecs used to encode the file
          unless $CHILD_STATUS.success?
            file_error(new_encode, input_url)
            return new_encode
          end

          # Write the mediainfo output to a temp file to preserve metadata from original file
          `#{MEDIAINFO_PATH} --Output=XML --LogFile=#{working_path("duration_input_metadata", new_encode.id)} "#{ActiveEncode.sanitize_uri(copy_path)}"`

          File.delete(copy_path)

          # Assign duration to the encode created for the original file.
          new_encode.input.duration = fixed_duration(working_path("duration_input_metadata", new_encode.id))
        end

        # For saving filename to label map used to find the label when building outputs
        filename_label_hash = {}

        # Copy derivatives to work directory
        options[:outputs].each do |opt|
          url = opt[:url]
          output_path = working_path("outputs/#{ActiveEncode.sanitize_base opt[:url]}#{File.extname opt[:url]}", new_encode.id)
          FileUtils.cp FileLocator.new(url).location, output_path
          filename_label_hash[output_path] = opt[:label]
        end

        # Write filename-to-label map so we can retrieve them on build_output
        File.write working_path("filename_label.yml", new_encode.id), filename_label_hash.to_yaml

        new_encode.percent_complete = 1
        new_encode.state = :running
        new_encode.errors = []

        new_encode
      rescue StandardError => e
        new_encode.state = :failed
        new_encode.percent_complete = 1
        new_encode.errors = [e.full_message]
        write_errors new_encode
        new_encode
      end

      # Return encode object from file system
      def find(id, opts = {})
        encode_class = opts[:cast]
        encode_class ||= ActiveEncode::Base
        encode = encode_class.new(nil, opts)
        encode.id = id
        encode.created_at, encode.updated_at = get_times encode.id
        encode.input = build_input encode
        encode.input.id = encode.id
        encode.output = []
        encode.current_operations = []

        encode.errors = read_errors(id)
        if encode.errors.present?
          encode.state = :failed
          encode.percent_complete = 1
        elsif cancelled?(id)
          encode.state = :cancelled
          encode.percent_complete = 1
        elsif completed?(id)
          encode.state = :completed
          encode.percent_complete = 100
        else
          encode.output = build_outputs encode
          encode.state = :completed
          encode.percent_complete = 100
        end

        encode
      rescue StandardError => e
        encode.state = :failed
        encode.percent_complete = 1
        encode.errors = [e.full_message]
        write_errors encode
        encode
      end

      # Cancel ongoing encode using pid file
      def cancel(id)
        # Check for errors and if not then create cancelled file else raise CancelError?
        if running?(id)
          File.write(working_path("cancelled", id), "")
          find id
        else
          raise CancelError
        end
      end

    private

      def running?(id)
        !cancelled?(id) || !failed?(id) || !completed?(id)
      end

      def cancelled?(id)
        File.exist? working_path("cancelled", id)
      end

      def failed?(id)
        read_errors(id).present?
      end

      def completed?(id)
        File.exist? working_path("completed", id)
      end

      def get_times(id)
        updated_at = if File.file? working_path("completed", id)
                       File.mtime(working_path("completed", id))
                     elsif File.file? working_path("cancelled", id)
                       File.mtime(working_path("cancelled", id))
                     elsif File.file? working_path("error.log", id)
                       File.mtime(working_path("error.log", id))
                     else
                       File.mtime(working_path("input_metadata", id))
                     end

        [File.mtime(working_path("input_metadata", id)), updated_at]
      end

      def write_errors(encode)
        File.write(working_path("error.log", encode.id), encode.errors.join("\n"))
      end

      def read_errors(id)
        err_path = working_path("error.log", id)
        error = File.read(err_path) if File.file? err_path
        if error.present?
          [error]
        else
          []
        end
      end

      def build_input(encode)
        input = ActiveEncode::Input.new
        metadata = get_tech_metadata(working_path("input_metadata", encode.id))
        input.url = metadata[:url]
        input.assign_tech_metadata(metadata)
        created_at = File.mtime(working_path("input_metadata", encode.id))
        input.created_at = created_at
        input.updated_at = created_at

        input
      end

      def build_outputs(encode)
        id = encode.id
        outputs = []
        filename_label_hash = YAML.safe_load(File.read(working_path("filename_label.yml", id))) if File.exist?(working_path("filename_label.yml", id))
        Dir["#{File.absolute_path(working_path('outputs', id))}/*"].each do |file_path|
          output = ActiveEncode::Output.new
          output.url = "file://#{file_path}"
          output.label = filename_label_hash[file_path] if filename_label_hash
          output.id = "#{encode.input.id}-#{output.label}"
          output.created_at = encode.created_at
          output.updated_at = File.mtime file_path

          # Extract technical metadata from output file
          metadata_path = working_path("output_metadata-#{output.label}", id)
          `#{MEDIAINFO_PATH} --Output=XML --LogFile=#{metadata_path} #{ActiveEncode.sanitize_uri(output.url)}` unless File.file? metadata_path
          output.assign_tech_metadata(get_tech_metadata(metadata_path))

          outputs << output
        end
        File.write(working_path("completed", id), "")

        outputs
      end

      def working_path(path, id)
        File.join(WORK_DIR, id, path)
      end

      def get_tech_metadata(file_path)
        doc = Nokogiri::XML File.read(file_path)
        doc.remove_namespaces!
        duration = get_xpath_text(doc, '//Duration/text()', :to_f)
        duration *= 1000 unless duration.nil? # Convert to milliseconds
        { url: get_xpath_text(doc, '//media/@ref', :to_s),
          width: get_xpath_text(doc, '//Width/text()', :to_f),
          height: get_xpath_text(doc, '//Height/text()', :to_f),
          frame_rate: get_xpath_text(doc, '//FrameRate/text()', :to_f),
          duration: duration,
          file_size: get_xpath_text(doc, '//FileSize/text()', :to_i),
          audio_codec: get_xpath_text(doc, '//track[@type="Audio"]/CodecID/text()', :to_s),
          audio_bitrate: get_xpath_text(doc, '//track[@type="Audio"]/BitRate/text()', :to_i),
          video_codec: get_xpath_text(doc, '//track[@type="Video"]/CodecID/text()', :to_s),
          video_bitrate: get_xpath_text(doc, '//track[@type="Video"]/BitRate/text()', :to_i) }
      end

      def get_xpath_text(doc, xpath, cast_method)
        doc.xpath(xpath).first&.text&.send(cast_method)
      end

      def fixed_duration(path)
        get_tech_metadata(path)[:duration]
      end

      def file_error(new_encode, input_url)
        new_encode.state = :failed
        new_encode.percent_complete = 1

        new_encode.errors = if new_encode.input.file_size.blank?
                              ["#{input_url} does not exist or is not accessible"]
                            else
                              ["Error inspecting input: #{input_url}"]
                            end

        write_errors new_encode
        new_encode
      end
    end
  end
end
