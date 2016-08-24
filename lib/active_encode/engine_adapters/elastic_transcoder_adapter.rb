module ActiveEncode
  module EngineAdapters
    class ElasticTranscoderAdapter
      # TODO: add a stub for an input helper (supplied by an initializer) that transforms encode.input into a zencoder accepted url
      def create(encode)
        job = client.create_job(
          input: {key: encode.input},
          pipeline_id: encode.options[:pipeline_id],
          output_key_prefix: encode.options[:output_key_prefix],
          outputs: encode.options[:outputs]).job

        build_encode(get_job_details(job.id), encode.class)
      end

      def find(id, opts = {})
        build_encode(get_job_details(id), opts[:cast])
      end

      # TODO: implement list_jobs_by_pipeline and list_jobs_by_status
      def list(*_filters)
        fail NotImplementedError
      end

      # Can only cancel jobs with status = "Submitted"
      def cancel(encode)
        response = client.cancel_job(id: encode.id)
        build_encode(get_job_details(encode.id), encode.class) if response.successful?
      end

      def purge(_encode)
        fail NotImplementedError
      end

      def remove_output(_encode, _output_id)
        fail NotImplementedError
      end

      private

        # Needs region and credentials setup per http://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticTranscoder/Client.html
        def client
          @client ||= Aws::ElasticTranscoder::Client.new
        end

        def get_job_details(job_id)
          client.read_job(id: job_id).job
        end

        def build_encode(job, cast)
          return nil if job.nil?
          encode = cast.new(convert_input(job), convert_options(job))
          encode.id = job.id
          encode.state = convert_state(job)
          encode.current_operations = convert_current_operations(job)
          encode.percent_complete = convert_percent_complete(job)
          encode.created_at = convert_time(job.timing["submit_time_millis"])
          encode.updated_at = convert_time(job.timing["start_time_millis"])
          encode.finished_at = convert_time(job.timing["finish_time_millis"])
          encode.output = convert_output(job)
          encode.errors = convert_errors(job)
          encode.tech_metadata = convert_tech_metadata(job.input.detected_properties)
          encode
        end

        def convert_time(time_millis)
          return nil if time_millis.nil?
          Time.at(time_millis/1000).iso8601
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

        def convert_current_operations(job)
          current_ops = []
          current_ops
        end

        def convert_percent_complete(job)
          case job.status
          when "Submitted"
            10
          when "Progressing"
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
          output = []
          job.outputs.each do |o|
            output << convert_tech_metadata(o).merge(id: o.id, url: o.key, label: nil)
          end
          output
        end

        def convert_errors(job)
          job.outputs.select {|o| o.status == "Error" }.collect(&:status_detail).compact
        end

        def convert_tech_metadata(props)
          return {} if props.nil? || props.empty?

          metadata = {}
          props.each_pair do |key, value|
            next if value.nil?
            case key.to_s
            when "file_size"
              metadata[:file_size] = value
            when "duration_millis"
              metadata[:duration] = value
            when "frame_rate"
              metadata[:video_framerate] = value
            when "segment_duration"
              metadata[:segment_duration] = value
            when "width"
              metadata[:width] = value
            when "height"
              metadata[:height] = value
            end
          end

          metadata
        end
    end
  end
end
