require 'fileutils'
require 'nokogiri'

module ActiveEncode
  module EngineAdapters
    class FfmpegAdapter
      WORK_DIR = ENV["ENCODE_WORK_DIR"] || "encodes" # Should read from config

      def create(input_url, options = {})
        new_encode = ActiveEncode::Base.new(input_url, options)
        new_encode.id = SecureRandom.uuid
        new_encode.state = :running
        new_encode.current_operations = []
        new_encode.percent_complete = 10
        new_encode.errors = []
        new_encode.created_at = Time.new
        new_encode.updated_at = Time.new

        new_encode.input.url = input_url
        new_encode.input.created_at = new_encode.created_at
        new_encode.input.updated_at = new_encode.created_at

        new_encode.output = []

        # Create a working directory that holds all output files related to the encode
        FileUtils.mkdir_p working_path("", new_encode.id)

        # Extract technical metadata from input file
        `mediainfo --Output=XML --LogFile=#{working_path("input_metadata", new_encode.id)} #{input_url}`
        new_encode.input.assign_tech_metadata get_tech_metadata(working_path("input_metadata", new_encode.id))

        # Run the ffmpeg command and save its pid
        command = ffmpeg_command(new_encode, options)
        pid = Process.spawn(command)
        File.open(working_path("pid", new_encode.id), 'w') { |file| file.write pid }
        new_encode.input.id = pid

        # Prevent zombie process
        Process.detach(pid)

        new_encode
      end

      # Return encode object from file system
      def find(id, opts={})
        encode_class = opts[:cast]
        encode = ActiveEncode::Base.new(nil, opts)
        encode.id = id
        encode.errors = []
        encode.current_operations = []
        encode.created_at = File.mtime working_path("pid", id)
        encode.updated_at = File.mtime working_path("progress", id)

        pid = get_pid(id)
        encode.input.id = pid
        encode.input.url = "N/A"
        encode.input.created_at = encode.created_at
        encode.input.updated_at = encode.updated_at
        encode.input.assign_tech_metadata get_tech_metadata(working_path("input_metadata", encode.id))

        # Read progress data from file
        progress_data = File.read working_path("progress", id)
        encode.percent_complete = calculate_percent_complete encode, progress_data

        if running? pid
          encode.state = :running
          encode.current_operations = ["transcoding"]
        else
          error = File.read working_path("error.log", id)
          if error.present?
            encode.state = :failed
            encode.errors = [error]
          elsif progress_ended?(progress_data) && encode.percent_complete == 100
            encode.state = :completed
          elsif encode.percent_complete < 100
            encode.state = :cancelled
          end
        end

        if encode.completed?
          encode.output = build_output encode
        else
          encode.output = []
        end

        encode
      end

      # Cancel ongoing encode using pid file
      def cancel(id)
        pid = get_pid(id)
        Process.kill 'SIGTERM', pid.to_i

        find id
      end

private

      def build_output encode
        id = encode.id
        outputs = []
        Dir["#{File.absolute_path(working_path('', id))}/*.mp4"].each do |file_path|
          output = ActiveEncode::Output.new
          output.id = encode.input.id
          output.url = "file://#{file_path}"
          output.label = file_path[/(?!.*\-)(.*?)\.mp4/m, 1]
          output.created_at = encode.created_at
          output.updated_at = File.mtime file_path

          # Extract technical metadata from output file
          metadata_path = working_path("output_metadata-#{output.label}", id)
          `mediainfo --Output=XML --LogFile=#{metadata_path} #{output.url}`
          output.assign_tech_metadata get_tech_metadata(metadata_path)

          outputs << output
        end

        outputs
      end

      def ffmpeg_command(encode, opts)
        input_url = encode.input.url
        output_opt = opts[:output].collect do |output|
          file_name = File.basename(input_url, File.extname(input_url))
          "-s #{output[:ffmpeg_opt]} file_name-#{output[:label]}.mp4"
        end.join(" ")

        "ffmpeg -y -loglevel error -progress #{working_path("progress", encode.id)} -i #{input_url} #{output_opt} > #{working_path("error.log", encode.id)} 2>&1"
      end

      def get_pid(id)
        File.read(working_path("pid", id)).remove("\n")
      end

      def working_path(path, id)
        File.join(WORK_DIR, id, path)
      end

      def running?(pid)
        begin
          Process.getpgid pid.to_i
          true
        rescue Errno::ESRCH
          false
        end
      end

      def calculate_percent_complete encode, data
        (progress_value("out_time_ms=", data).to_i * 0.0001 / encode.input.duration).round
      end

      def progress_ended? data
        "end" == progress_value("progress=", data)
      end

      def progress_value key, data
        ri = data.rindex(key) + key.length
        data[ri..data.index("\n", ri)-1]
      end

      def get_tech_metadata file_path
        doc = Nokogiri::XML File.read(file_path)
        doc.remove_namespaces!
        { width: get_xpath_text(doc, '//Width/text()', :to_f),
          height: get_xpath_text(doc, '//Height/text()', :to_f),
          frame_rate: get_xpath_text(doc, '//FrameRate/text()', :to_f),
          duration: get_xpath_text(doc, '//Duration/text()', :to_f),
          file_size: get_xpath_text(doc, '//FileSize/text()', :to_i),
        #   checksum: doc.xpath('//Duration/text()').first.text.to_f,
          audio_codec: get_xpath_text(doc, '//track[@type="Audio"]/CodecID/text()', :to_i),
          audio_bitrate: get_xpath_text(doc, '//track[@type="Audio"]/BitRate/text()', :to_i),
          video_codec: get_xpath_text(doc, '//track[@type="Video"]/CodecID/text()', :to_i),
          video_bitrate: get_xpath_text(doc, '//track[@type="Video"]/BitRate/text()', :to_i) }
      end

      def get_xpath_text doc, xpath, cast_method
        if doc.xpath(xpath).first
          doc.xpath(xpath).first.text.send(cast_method)
        else
          nil
        end
      end
    end
  end
end
