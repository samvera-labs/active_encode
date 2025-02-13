# frozen_string_literal: true
require 'English'
require 'fileutils'
require 'nokogiri'
require 'shellwords'
require 'addressable/uri'
require 'active_encode/engine_adapters/ffmpeg_adapter/cleaner'

module ActiveEncode
  module EngineAdapters
    class FfmpegAdapter
      extend ActiveEncode::EngineAdapters::FfmpegAdapter::Cleaner

      WORK_DIR = ENV["ENCODE_WORK_DIR"] || "encodes" # Should read from config
      MEDIAINFO_PATH = ENV["MEDIAINFO_PATH"] || "mediainfo"
      FFMPEG_PATH = ENV["FFMPEG_PATH"] || "ffmpeg"

      class_attribute :completeness_threshold

      def create(input_url, options = {})
        # Decode file uris for ffmpeg (mediainfo works either way)
        case input_url
        when /^file\:\/\/\//
          input_url = Addressable::URI.unencode(input_url)
          input_url = ActiveEncode.sanitize_input(input_url)
        when /^s3\:\/\//
          require 'file_locator'

          s3_object = FileLocator::S3File.new(input_url).object
          input_url = URI.parse(s3_object.presigned_url(:get))
        when /^https?\:\/\//
          input_url = URI.parse(input_url)
        end

        new_encode = ActiveEncode::Base.new(input_url, options)
        new_encode.id = SecureRandom.uuid
        new_encode.created_at = Time.now.utc
        new_encode.updated_at = Time.now.utc
        new_encode.current_operations = []
        new_encode.output = []

        # Create a working directory that holds all output files related to the encode
        FileUtils.mkdir_p working_path("", new_encode.id)
        FileUtils.mkdir_p working_path("outputs", new_encode.id)
        FileUtils.mkdir_p working_path("supplemental_files", new_encode.id)

        # Extract technical metadata from input file
        curl_option = if options && options[:headers]
                        headers = options[:headers].map { |k, v| "#{k}: #{v}" }
                        (["--File_curl=HttpHeader"] + headers).join(",").yield_self { |s| "'#{s}'" }
                      else
                        ""
                      end

        clean_url = input_url.is_a?(String) ? ActiveEncode.sanitize_uri(input_url) : input_url

        `#{MEDIAINFO_PATH} #{curl_option} --Output=XML --LogFile=#{working_path("input_metadata", new_encode.id)} "#{clean_url}"`

        new_encode.input = build_input new_encode

        # Log error if file is empty or inaccessible
        if new_encode.input.duration.blank? && new_encode.input.file_size.blank?
          file_error(new_encode, input_url)
          return new_encode
        # If file is not empty, try copying file to generate missing metadata
        elsif new_encode.input.duration.blank? && new_encode.input.file_size.present?

          # This regex removes the query string from URIs. This is necessary to
          # properly process files originating from S3 or similar providers.
          filepath = clean_url.to_s.gsub(/\?.*/, '')
          copy_url = filepath.gsub(filepath, "#{File.basename(filepath, File.extname(filepath))}_temp#{File.extname(filepath)}")
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

          # Write the mediainfo output to a separate file to preserve metadata from original file
          `#{MEDIAINFO_PATH} #{curl_option} --Output=XML --LogFile=#{working_path("duration_input_metadata", new_encode.id)} "#{copy_path}"`

          File.delete(copy_path)

          # Assign duration to the encode created for the original file.
          new_encode.input.duration = fixed_duration(working_path("duration_input_metadata", new_encode.id))
        end

        subtitle_count = new_encode.input.subtitles.length if new_encode.input.subtitles.present?

        new_encode.state = :running
        new_encode.percent_complete = 1
        new_encode.errors = []

        # Run the ffmpeg command and save its pid
        command = ffmpeg_command(input_url, new_encode.id, options, subtitle_count)
        # Capture the exit status in a file in order to differentiate warning output in stderr between real process failure
        exit_status_file = working_path("exit_status.code", new_encode.id)
        command = "#{command}; echo $? > #{exit_status_file}"
        pid = Process.spawn(command, err: working_path('error.log', new_encode.id))
        File.open(working_path("pid", new_encode.id), 'w') { |file| file.write pid }
        new_encode.input.id = pid

        new_encode
      rescue StandardError => e
        new_encode.state = :failed
        new_encode.percent_complete = 1
        new_encode.errors = [e.full_message]
        write_errors new_encode
        new_encode
      ensure
        # Prevent zombie process
        Process.detach(pid) if pid.present?
      end

      # Return encode object from file system
      def find(id, opts = {})
        encode_class = opts[:cast]
        encode_class ||= ActiveEncode::Base
        encode = encode_class.new(nil, opts)
        encode.id = id
        encode.output = []
        encode.created_at, encode.updated_at = get_times encode.id
        encode.input = build_input encode
        encode.input.duration ||= fixed_duration(working_path("duration_input_metadata", encode.id)) if File.exist?(working_path("duration_input_metadata", encode.id))
        encode.percent_complete = calculate_percent_complete encode

        pid = get_pid(id)
        encode.input.id = pid if pid.present?

        encode.current_operations = []
        encode.created_at, encode.updated_at = get_times encode.id
        encode.errors = read_errors(id)
        exit_code = read_exit_code(id)
        if exit_code.present? && exit_code != 0 && exit_code != 143
          encode.state = :failed
        elsif running? pid
          encode.state = :running
          encode.current_operations = ["transcoding"]
        elsif progress_ended?(encode.id) && encode.percent_complete == 100
          encode.state = :completed
        elsif cancelled? encode.id
          encode.state = :cancelled
        elsif encode.percent_complete < (completeness_threshold || 100)
          encode.errors.prepend("Encoding has completed but the output duration is shorter than the input")
          encode.state = :failed
        end

        encode.output = build_outputs encode if encode.completed?
        encode.output += build_supplemental_outputs encode if encode.completed?

        encode
      end

      # Cancel ongoing encode using pid file
      def cancel(id)
        encode = find id
        if encode.running?
          pid = get_pid(id)

          IO.popen("ps -ef | grep #{pid}") do |pipe|
            child_pids = pipe.readlines.map do |line|
              parts = line.split(/\s+/)
              parts[1] if parts[2] == pid.to_s && parts[1] != pipe.pid.to_s
            end.compact

            child_pids.each do |cpid|
              Process.kill 'SIGTERM', cpid.to_i
            end
          end

          Process.kill 'SIGTERM', pid.to_i
          File.write(working_path("cancelled", id), "")
          encode = find id
        end
        encode
      rescue Errno::ESRCH
        raise NotRunningError
      rescue StandardError
        raise CancelError
      end

    private

      def get_times(id)
        updated_at = if File.file? working_path("progress", id)
                       File.mtime(working_path("progress", id))
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
          ["Error encountered during encoding. Check ffmpeg log for more details.", error]
        else
          []
        end
      end

      def read_exit_code(id)
        exit_path = working_path("exit_status.code", id)
        exit_status = File.read(exit_path) if File.file? exit_path
        exit_status.present? ? exit_status.to_i : nil # process still running
      end

      def build_input(encode)
        input = ActiveEncode::Input.new
        metadata = get_tech_metadata(working_path("input_metadata", encode.id))
        input.url = metadata[:url]
        input.assign_tech_metadata(metadata)
        input.created_at = encode.created_at
        input.updated_at = encode.created_at
        input.id = "N/A"

        input
      end

      def build_outputs(encode)
        id = encode.id
        outputs = []
        Dir["#{File.absolute_path(working_path('outputs', id))}/*"].each do |file_path|
          output = ActiveEncode::Output.new
          output.url = "file://#{file_path}"
          sanitized_filename = encode.input.url.match?(/^https?\:\/\//) ? ActiveEncode.sanitize_base(URI.parse(encode.input.url)) : ActiveEncode.sanitize_base(encode.input.url)
          output.label = file_path[/#{Regexp.quote(sanitized_filename)}.*\-(.*?)#{Regexp.quote(File.extname(file_path))}$/, 1]
          output.id = "#{encode.input.id}-#{output.label}"
          output.created_at = encode.created_at
          output.updated_at = File.mtime file_path

          # Extract technical metadata from output file
          metadata_path = working_path("output_metadata-#{output.label}", id)
          `#{MEDIAINFO_PATH} --Output=XML --LogFile=#{metadata_path} #{output.url}` unless File.file? metadata_path
          output.assign_tech_metadata(get_tech_metadata(metadata_path))

          outputs << output
        end

        outputs
      end

      def build_supplemental_outputs(encode)
        id = encode.id
        files = []
        Dir["#{File.absolute_path(working_path('supplemental_files', id))}/*"].each_with_index do |file_path, index|
          file = ActiveEncode::Output.new
          file.url = "file://#{file_path}"
          file.id = "#{encode.input.id}-#{File.basename(file_path)}"
          file.created_at = encode.created_at
          file.updated_at = File.mtime file_path
          file.label = encode.input.subtitles[index][:label]
          file.language = encode.input.subtitles[index][:language]
          file.format = 'vtt'

          files << file
        end

        files
      end

      def ffmpeg_command(input_url, id, opts, subtitle_count = nil)
        sanitized_filename = ActiveEncode.sanitize_base input_url
        output_opt = opts[:outputs].collect do |output|
          file_name = "outputs/#{sanitized_filename}-#{output[:label]}.#{output[:extension]}"
          " #{output[:ffmpeg_opt]} #{working_path(file_name, id)}"
        end.join(" ")

        supplemental_file_opt = if opts[:extract_subtitles] && subtitle_count.present?
                                  caption_extraction_options(sanitized_filename, subtitle_count, id)
                                end

        header_opt = Array(opts[:headers]).map do |k, v|
          "#{k}: #{v}\r\n"
        end.join
        header_opt = "-headers '#{header_opt}'" if header_opt.present?
        "#{FFMPEG_PATH} #{header_opt} -y -loglevel level+fatal -progress #{working_path('progress', id)} -i \"#{input_url}\" #{supplemental_file_opt} #{output_opt}"
      end

      def caption_extraction_options(filename, count, id)
        opts = ""
        (0..count - 1).each do |i|
          subtitle_filename = "supplemental_files/#{filename}-caption#{i}.vtt"
          opts += " -map 0:s:#{i} -c:s webvtt #{working_path(subtitle_filename, id)}"
        end

        opts
      end

      def get_pid(id)
        File.read(working_path("pid", id)).remove("\n") if File.file? working_path("pid", id)
      end

      def working_path(path, id)
        File.join(WORK_DIR, id, path)
      end

      def running?(pid)
        Process.getpgid pid.to_i
        true
      rescue Errno::ESRCH
        false
      end

      def calculate_percent_complete(encode)
        data = read_progress encode.id
        if data.blank?
          1
        else
          progress_in_milliseconds = progress_value("out_time_ms=", data).to_i / 1000.0
          output = (progress_in_milliseconds / encode.input.duration * 100).ceil
          return 100 if output > 100
          output
        end
      end

      def cancelled?(id)
        File.exist? working_path("cancelled", id)
      end

      def read_progress(id)
        File.read working_path("progress", id) if File.file? working_path("progress", id)
      end

      def progress_ended?(id)
        "end" == progress_value("progress=", read_progress(id))
      end

      def progress_value(key, data)
        return nil unless data.present? && key.present?
        ri = data.rindex(key) + key.length
        data[ri..data.index("\n", ri) - 1]
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
          video_bitrate: get_xpath_text(doc, '//track[@type="Video"]/BitRate/text()', :to_i),
          subtitles: get_subtitle_tech_metadata(doc).compact }
      end

      def get_xpath_text(doc, xpath, cast_method)
        doc.xpath(xpath).first&.text&.send(cast_method)
      end

      def get_subtitle_tech_metadata(doc)
        doc.xpath("//track[@type='Text' and Format='Timed Text']").collect do |track|
          {
            format: get_xpath_text(track, "./CodecID/text()", :to_s),
            label: get_xpath_text(track, "./Title/text()", :to_s),
            language: get_xpath_text(track, "./Language/text()", :to_s)
          }
        end
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
