module ActiveEncode
  module EngineAdapters
    class ElasticTranscoderAdapter
      # TODO: add a stub for an input helper (supplied by an initializer) that transforms encode.input into a zencoder accepted url
      def create(input_url, options = {})
        job = client.create_job(
          input: { key: input_url },
          pipeline_id: options[:pipeline_id],
          output_key_prefix: options[:output_key_prefix],
          outputs: options[:outputs],
          user_metadata: options[:user_metadata]
        ).job

        build_encode(job)
      end

      def find(id, opts = {})
        build_encode(get_job_details(id))
      end

      # Can only cancel jobs with status = "Submitted"
      def cancel(id)
        response = client.cancel_job(id: id)
        build_encode(get_job_details(id)) if response.successful?
      end

      private

        # Needs region and credentials setup per http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticTranscoder/Client.html
        def client
          @client ||= Aws::ElasticTranscoder::Client.new
        end

        def get_job_details(job_id)
          client.read_job(id: job_id).job
        end

        def build_encode(job)
          return nil if job.nil?
          encode = ActiveEncode::Base.new(convert_input(job), convert_options(job))
          encode.id = job.id
          encode.state = convert_state(job)
          encode.current_operations = convert_current_operations(job)
          encode.percent_complete = convert_percent_complete(job)
          encode.created_at = convert_time(job.timing["submit_time_millis"])
          encode.updated_at = convert_time(job.timing["finish_time_millis"] || job.timing["start_time_millis"]) || encode.created_at
          encode.output = convert_output(job)
          encode.errors = convert_errors(job)

          encode.input.id = job.input.key
          tech_md = convert_tech_metadata(job.input.detected_properties)
          [:width, :height, :frame_rate, :duration, :checksum, :audio_codec, :video_codec,
           :audio_bitrate, :video_bitrate, :file_size].each do |field|
            encode.input.send("#{field}=", tech_md[field])
          end
          encode.input.state = encode.state
          encode.input.created_at = encode.created_at
          encode.input.updated_at = encode.updated_at

          encode
        end

        def convert_time(time_millis)
          return nil if time_millis.nil?
          Time.at(time_millis / 1000)
        end

        def convert_state(job)
          case job.status
          when "Submitted", "Progressing" # Should there be a queued state?
            :running
          when "Canceled"
            :cancelled
          when "Error"
            :failed
          when "Complete"
            :completed
          end
        end

        def convert_current_operations(_job)
          current_ops = []
          current_ops
        end

        def convert_percent_complete(job)
          case job.status
          when "Submitted"
            10
          when "Progressing", "Canceled", "Error"
            50
          when "Complete"
            100
          else
            0
          end
        end

        def convert_input(job)
          job.input
        end

        def convert_options(_job_details)
          {}
        end

        def convert_output(job)
          job.outputs.collect do |o|
            # It is assumed that the first part of the output key can be used to label the  output
            # e.g. "quality-medium/somepath/filename.flv"
            output = ActiveEncode::Output.new
            output.id = o.id
            output.label = o.key.split("/", 2).first
            output.url = job.output_key_prefix + o.key
            # extras = { id: o.id, url: url, label: label }
            # extras[:hls_url] = url + ".m3u8" if url.include?("/hls/") # TODO: find a better way to signal hls
            tech_md = convert_tech_metadata(o)
            [:width, :height, :frame_rate, :duration, :checksum, :audio_codec, :video_codec,
             :audio_bitrate, :video_bitrate, :file_size].each do |field|
              output.send("#{field}=", tech_md[field])
            end
            output.state = convert_state(o)
            output.created_at = convert_time(job.timing["submit_time_millis"])
            output.updated_at = convert_time(job.timing["finish_time_millis"] || job.timing["start_time_millis"]) || output.created_at

            output
          end
        end

        def convert_errors(job)
          job.outputs.select { |o| o.status == "Error" }.collect(&:status_detail).compact
        end

        def convert_tech_metadata(props)
          return {} if props.blank?
          metadata_fields = {
            file_size: { key: :file_size, method: :itself },
            duration_millis: { key: :duration, method: :to_i },
            frame_rate: { key: :frame_rate, method: :to_i },
            width: { key: :width, method: :itself },
            height: { key: :height, method: :itself }
          }

          metadata = {}
          props.each_pair do |key, value|
            next if value.nil?
            conversion = metadata_fields[key.to_sym]
            next if conversion.nil?
            metadata[conversion[:key]] = value.send(conversion[:method])
          end
          metadata
        end
    end
  end
end
