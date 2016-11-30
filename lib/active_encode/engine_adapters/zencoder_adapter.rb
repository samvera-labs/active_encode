module ActiveEncode
  module EngineAdapters
    class ZencoderAdapter
      # TODO: add a stub for an input helper (supplied by an initializer) that transforms encode.input into a zencoder accepted url
      def create(encode)
        response = Zencoder::Job.create(input: encode.input.to_s)
        build_encode(get_job_details(response.body["id"]), encode.class)
      end

      def find(id, opts = {})
        build_encode(get_job_details(id), opts[:cast])
      end

      def list(*_filters)
        raise NotImplementedError
      end

      def cancel(encode)
        response = Zencoder::Job.cancel(encode.id)
        build_encode(get_job_details(encode.id), encode.class) if response.success?
      end

      def purge(_encode)
        raise NotImplementedError
      end

      def remove_output(_encode, _output_id)
        raise NotImplementedError
      end

      private

        def get_job_details(job_id)
          Zencoder::Job.details(job_id)
        end

        def get_job_progress(job_id)
          Zencoder::Job.progress(job_id)
        end

        def build_encode(job_details, cast)
          return nil if job_details.nil?
          encode = cast.new(convert_input(job_details), convert_options(job_details))
          encode.id = job_details.body["job"]["id"].to_s
          encode.state = convert_state(job_details)
          job_progress = get_job_progress(encode.id)
          encode.current_operations = convert_current_operations(job_progress)
          encode.percent_complete = convert_percent_complete(job_progress, job_details)
          encode.created_at = job_details.body["job"]["created_at"]
          encode.updated_at = job_details.body["job"]["updated_at"]
          encode.finished_at = job_details.body["job"]["finished_at"]
          encode.output = convert_output(job_details)
          encode.errors = convert_errors(job_details)
          encode.tech_metadata = convert_tech_metadata(job_details.body["job"]["input_media_file"])
          encode
        end

        def convert_state(job_details)
          case job_details.body["job"]["state"]
          when "pending", "waiting", "processing" # Should there be a queued state?
            :running
          when "cancelled"
            :cancelled
          when "failed"
            :failed
          when "finished"
            :completed
          end
        end

        def convert_current_operations(job_progress)
          current_ops = []
          job_progress.body["outputs"].each { |output| current_ops << output["current_event"] unless output["current_event"].nil? }
          current_ops
        end

        def convert_percent_complete(job_progress, job_details)
          percent = job_progress.body["progress"]
          percent ||= 100 if convert_state(job_details) == :completed
          percent ||= 0
          percent
        end

        def convert_input(job_details)
          job_details.body["job"]["input_media_file"]["url"]
        end

        def convert_options(_job_details)
          {}
        end

        def convert_output(job_details)
          output = []
          job_details.body["job"]["output_media_files"].each do |o|
            track_id = o["id"].to_s
            label = o["label"]
            url = o["url"]
            output << convert_tech_metadata(o).merge(id: track_id, url: url, label: label)
          end
          output
        end

        def convert_errors(job_details)
          errors = []
          input_error = job_details.body["job"]["input_media_file"]["error_message"]
          errors << input_error unless input_error.blank?
          job_details.body["job"]["output_media_files"].each { |o| errors << o["error_message"] unless o["error_message"].blank? }
          errors
        end

        def convert_tech_metadata(media_file)
          return {} if media_file.nil?

          metadata = {}
          media_file.each_pair do |key, value|
            next if value.blank?
            case key
            when "md5_checksum"
              metadata[:checksum] = value
            when "format"
              metadata[:mime_type] = value
            when "duration_in_ms"
              metadata[:duration] = value.to_s
            when "audio_codec"
              metadata[:audio_codec] = value.to_s
            when "channels"
              metadata[:audio_channels] = value.to_s
            when "audio_bitrate_in_kbps"
              metadata[:audio_bitrate] = value.to_s
            when "video_codec"
              metadata[:video_codec] = value
            when "frame_rate"
              metadata[:video_framerate] = value.to_s
            when "video_bitrate_in_kbps"
              metadata[:video_bitrate] = value.to_s
            when "width"
              metadata[:width] = value.to_s
            when "height"
              metadata[:height] = value.to_s
            end
          end
          metadata
        end
    end
  end
end
