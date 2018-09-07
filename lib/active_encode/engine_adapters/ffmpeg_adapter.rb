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
        new_encode.input.updated_at = Time.new + 10

        # Create a working directory that holds all output files related to the encode
        FileUtils.mkdir_p working_path("", new_encode.id)

        # Extract technical metadata from input file
        `mediainfo --Output=XML --LogFile=#{working_path("input_metadata", new_encode.id)} #{input_url}`
        new_encode.input.assign_tech_metadata get_tech_metadata(working_path("input_metadata", new_encode.id))

        # Run the ffmpeg command and save its pid
        command = "ffmpeg -y -loglevel error -progress progress -i #{input_url} low.mp4 > error.log 2>&1 < /dev/null &"
        pid = Process.spawn(command)
        File.open(working_path("pid", new_encode.id), 'w') { |file| file.write pid }
        new_encode.input.id = pid

        # Prevent zombie process
        Process.detach(pid)

        new_encode.output = []

        new_encode
      end

      # Return encode object from file system
      def find(id, opts={})
        encode_class = opts[:cast]
        encode = ActiveEncode::Base.new(nil, opts)
        encode.id = id
        encode.errors = []
        encode.current_operations = []

        # Read progress data from file
        progress_data = File.read working_path("progress", id)
        encode.percent_complete = calculate_percent_complete progress_data

        pid = File.read working_path("pid", id)
        if running? pid
          encode.state = :running
          encode.current_operations = ["transcoding"]
        else
          error = File.read working_path("error.log", id)
          if error
            encode.state = :failed
            encode.errors = [error]
          elsif encode.percent_complete < 100
            encode.state = :canceled
          elsif progress_ended? progress_data
            encode.state = :completed
          end
        end

        encode.created_at = File.mtime working_path("pid", id)
        encode.updated_at = File.mtime(working_path("progress", id))

        encode.input.id = pid
        encode.input.url = "N/A"
        encode.input.created_at = encode.created_at
        encode.input.updated_at = encode.updated_at
        encode.input.assign_tech_metadata get_tech_metadata(working_path("input_metadata", encode.id))

        if encode.state == :completed
          output = ActiveEncode::Output.new
          output.id = pid
          output.url = "file://#{File.absolute_path(working_path('low.mp4', id))}"
          output.label = "low"
          output.created_at = encode.created_at
          output.updated_at = File.mtime File.absolute_path(working_path('low.mp4', id))

          # Extract technical metadata from output file
          `mediainfo --Output=XML --LogFile=#{working_path("output_metadata", id)} #{output.url}`
          output.assign_tech_metadata get_tech_metadata(working_path("output_metadata", id))

          encode.output = [output]
        else
          encode.output = []
        end
        
        encode
      end

      # Cancel ongoing encode using pid file
      def cancel(encode)

      end

private
      def working_path(path, id)
        File.join(WORK_DIR, id, path)
      end

      def running?(pid)
        begin
          Process.getpgid pid
          true
        rescue Errno::ESRCH
          false
        end
      end

      def calculate_percent_complete data
        progress_value("out_time_ms=", data).to_i
      end

      def progress_ended? data
        "end" == progress_value("progress=", data)
      end

      def progress_value key, data
        ri = data.rindex(key) + key.length
        data[ri..data.index("\n", ri)-2]
      end

      def get_tech_metadata file_path
        doc = Nokogiri::XML File.read(file_path)
        doc.remove_namespaces!

        { width: doc.xpath('//Width/text()').first.text.to_f,
          height: doc.xpath('//Height/text()').first.text.to_f,
          frame_rate: doc.xpath('//FrameRate/text()').first.text.to_f,
          duration: doc.xpath('//Duration/text()').first.text.to_f,
          file_size: doc.xpath('//FileSize/text()').first.text.to_i,
        #   checksum: doc.xpath('//Duration/text()').first.text.to_f,
          audio_codec: doc.xpath('//track[@type="Audio"]/CodecID/text()').first.text.to_i,
          audio_bitrate: doc.xpath('//track[@type="Audio"]/BitRate/text()').first.text.to_i,
          video_codec: doc.xpath('//track[@type="Video"]/CodecID/text()').first.text.to_i,
          video_bitrate: doc.xpath('//track[@type="Video"]/BitRate/text()').first.text.to_i }
      end
    end
  end
end
