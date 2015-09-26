require 'active_support'
require 'active_support/core_ext'

module ActiveEncode
  module EngineAdapters
    class ShingoncoderAdapter < ZencoderAdapter
      # @param [ActiveEncode::Base] encode
      def create(encode)
        response = Shingoncoder::Job.create(input: encode.input)
        build_encode(job_details(response.body["id"]), encode.class)
      end

      # @param [Fixnum] id
      # @param [Hash] opts
      # @option opts :cast the class to cast the encoding job to.
      def find(id, opts = {})
        build_encode(job_details(id), opts[:cast])
      end

      # @param [ActiveEncode::Base] encode
      def cancel(encode)
        response = Shingoncoder::Job.cancel(encode.id)
        build_encode(job_details(encode.id), encode.class) if response.success?
      end

      private

        # @param [Fixnum] job_id the identifier for the job
        # @return [Shingoncoder::Response] the response from Shingoncoder
        def job_details(job_id)
          Shingoncoder::Job.details(job_id)
        end

        # @return [Shingoncoder::Response] the response from Shingoncoder
        def job_progress(job_id)
          Shingoncoder::Job.progress(job_id)
        end

        # @param [Shingoncoder::Response] job_details
        # @param [Class] cast the class of object to instantiate and return
        def build_encode(job_details, cast)
          return nil if job_details.nil?
          encode = cast.new(convert_input(job_details), convert_options(job_details))
          encode.id = job_details.body["job"]["id"].to_s
          encode.state = convert_state(job_details)
          progress = job_progress(encode.id)
          encode.current_operations = convert_current_operations(progress)
          encode.percent_complete = convert_percent_complete(progress, job_details)
          encode.output = convert_output(job_details)
          encode.errors = convert_errors(job_details)
          encode.tech_metadata = convert_tech_metadata(job_details.body["job"]["input_media_file"])
          encode
        end
    end
  end
end
