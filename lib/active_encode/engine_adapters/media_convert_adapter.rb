# frozen_string_literal: true
require 'active_encode/engine_adapters/media_convert_output.rb'
require 'active_support/core_ext/integer/time'
require 'addressable/uri'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-cloudwatchlogs'
require 'aws-sdk-mediaconvert'
require 'file_locator'

require 'active_support/json'
require 'active_support/time'

module ActiveEncode
  module EngineAdapters
    # An adapter for using [AWS Elemental MediaConvert](https://aws.amazon.com/mediaconvert/) to
    # encode.
    #
    # Note: this adapter does not perform input characterization, does not provide technical
    # metadata on inputs.
    #
    # ## Configuration
    #
    #     ActiveEncode::Base.engine_adapter = :media_convert
    #
    #     ActiveEncode::Base.engine_adapter.role = 'arn:aws:iam::123456789012:role/service-role/MediaConvert_Default_Role'
    #     ActiveEncode::Base.engine_adapter.output_bucket = 'output-bucket'
    #
    #     # optionally and probably not needed
    #
    #     ActiveEncode::Base.engine_adapter.queue = my_mediaconvert_queue_name
    #     ActiveEncode::Base.engine_adapter.log_group = my_log_group_name
    #
    # ## Capturing output information
    #
    # [AWS Elemental MediaConvert](https://aws.amazon.com/mediaconvert/) doesn't provide detailed
    # output information in the job description that can be pulled directly from the service.
    # Instead, it provides that information along with the job status notification when the job
    # status changes to `COMPLETE`. The only way to capture that notification is through an [Amazon
    # Eventbridge](https://aws.amazon.com/eventbridge/) rule that forwards the a MediaWatch job
    # status change on `COMPLETE` to another service, such as [CloudWatch Logs]
    # (https://aws.amazon.com/cloudwatch/) log group
    #
    # This adapter is written to get output information from a CloudWatch log group that has had
    # MediaWatch complete events forwarded to it by an EventBridge group. The `setup!` method
    # can be used to create these for you, at conventional names the adapter will be default use.
    #
    #      ActiveEncode::Base.engine_adapter.setup!
    #
    # **OR**, there is experimental functionality to get what we can directly from the job without
    # requiring a CloudWatch log -- this is expected to be complete only for  HLS output at present.
    # It seems to work well for HLS output. To opt-in, and not require CloudWatch logs:
    #
    #     ActiveEncode::Base.engine_adapter.direct_output_lookup = true
    #
    # ## Example
    #
    #     ActiveEncode::Base.engine_adapter = :media_convert
    #     ActiveEncode::Base.engine_adapter.role = 'arn:aws:iam::123456789012:role/service-role/MediaConvert_Default_Role'
    #     ActiveEncode::Base.engine_adapter.output_bucket = 'output-bucket'
    #
    #     ActiveEncode::Base.engine_adapter.setup!
    #
    #     encode = ActiveEncode::Base.create(
    #       "file://path/to/file.mp4",
    #       {
    #         masterfile_bucket: "name-of-my-masterfile_bucket"
    #         output_prefix: "path/to/output/base_name_of_outputs",
    #         use_original_url: true,
    #         outputs: [
    #           { preset: "my-hls-preset-high", modifier: "_high" },
    #           { preset: "my-hls-preset-medium", modifier: "_medium" },
    #           { preset: "my-hls-preset-low", modifier: "_low" },
    #         ]
    #       }
    #     )
    #
    # ## More info
    #
    # A more detailed guide is available in the repo at [guides/media_convert_adapter.md](../../../guides/media_convert_adapter.md)
    class MediaConvertAdapter
      JOB_STATES = {
        "SUBMITTED" => :running, "PROGRESSING" => :running, "CANCELED" => :cancelled,
        "ERROR" => :failed, "COMPLETE" => :completed
      }.freeze

      OUTPUT_GROUP_TEMPLATES = {
        hls: { min_segment_length: 0, segment_control: "SEGMENTED_FILES", segment_length: 10 },
        dash_iso: { fragment_length: 2, segment_control: "SEGMENTED_FILES", segment_length: 30 },
        file: {},
        ms_smooth: { fragment_length: 2 },
        cmaf: { fragment_length: 2, segment_control: "SEGMENTED_FILES", segment_length: 10 }
      }.freeze

      SETUP_LOG_GROUP_RETENTION_DAYS = 3

      class ResultsNotAvailable < RuntimeError
        attr_reader :encode

        def initialize(msg = nil, encode = nil)
          @encode = encode
          super(msg)
        end
      end

      # @!attribute [rw] role simple name of AWS role to pass to MediaConvert, eg `my-role-name`
      # @!attribute [rw] output_bucket simple bucket name to write output to
      # @!attribute [rw] direct_output_lookup if true, do NOT get output information from cloudwatch,
      #                  instead retrieve and construct it only from job itself. Currently
      #                  working only for HLS output. default false.
      attr_accessor :role, :output_bucket, :direct_output_lookup

      # @!attribute [w] log_group log_group_name that is being used to capture output
      # @!attribute [w] queue name of MediaConvert queue to use.
      attr_writer :log_group, :queue

      # Creates a [CloudWatch Logs]
      # (https://aws.amazon.com/cloudwatch/) log group and an EventBridge rule to forward status
      # change notifications to the log group, to catch result information from MediaConvert jobs.
      #
      # Will use the configured `queue` and `log_group` values.
      #
      # The active AWS user/role when calling the `#setup!` method will require permissions to create the
      # necessary CloudWatch and EventBridge resources
      #
      # This method chooses a conventional name for the EventBridge rule, if a rule by that
      # name already exists, it will silently exit. So this method can be called in a boot process,
      # to check if this infrastructure already exists, and create it only if it does not.
      def setup!
        rule_name = "active-encode-mediaconvert-#{queue}"
        return true if event_rule_exists?(rule_name)

        queue_arn = mediaconvert.get_queue(name: queue).queue.arn

        event_pattern = {
          source: ["aws.mediaconvert"],
          "detail-type": ["MediaConvert Job State Change"],
          detail: {
            queue: [queue_arn],
            status: ["COMPLETE"]
          }
        }

        # AWS is inconsistent about whether a cloudwatch ARN has :* appended
        # to the end, and we need to make sure it doesn't in the rule target.
        log_group_arn = create_log_group(log_group).arn.chomp(":*")

        cloudwatch_events.put_rule(
          name: rule_name,
          event_pattern: event_pattern.to_json,
          state: "ENABLED",
          description: "Forward MediaConvert job state changes on COMPLETE from queue #{queue} to #{log_group}"
        )

        cloudwatch_events.put_targets(
          rule: rule_name,
          targets: [
            {
              id: "Id#{SecureRandom.uuid}",
              arn: log_group_arn
            }
          ]
        )
        true
      end

      # Required options:
      #
      # * `output_prefix`: The S3 key prefix to use as the base for all outputs. Will be
      #                    combined with configured `output_bucket` to be passed to MediaConvert
      #                    `destination`. Alternately see `destination` arg; one or the other
      #                    is required.
      #
      # * `destination`: The full s3:// URL to be passed to MediaConvert `destination` as output
      #                  location an filename base.  `output_bucket` config is ignored if you
      #                  pass `destination`. Alternately see `output_prefix` arg; one or the
      #                  other is required.
      #
      #
      # * `outputs`: An array of `{preset, modifier}` options defining how to transcode and
      #              name the outputs. The "modifier" option will be passed as `name_modifier`
      #              to AWS, to be added as a suffix on to `output_prefix` to create the
      #              filenames for each output.
      #
      # Optional options:
      #
      # * `masterfile_bucket`: All input will first be copied to this bucket, before being passed
      #                        to MediaConvert. You can skip this copy by passing `use_original_url`
      #                        option, and an S3-based input. `masterfile_bucket` **is** required
      #                        unless use_original_url is true and an S3 input source.
      #
      # * `use_original_url`: If `true`, any S3 URL passed in as input will be passed directly to
      #                       MediaConvert as the file input instead of copying the source to
      #                       the `masterfile_bucket`.
      #
      # * `media_type`: `audio` or `video`. Default `video`. Triggers use of a correspoinding
      #                  template for arguments sent to AWS create_job API.
      #
      #
      # * `output_type`: One of: `hls`, `dash_iso`, `file`, `ms_smooth`, `cmaf`. Default `hls`.
      #                  Triggers use of a corresponding template for arguments sent to AWS
      #                  create_job API.
      #
      #
      # Example:
      # {
      #   output_prefix: "path/to/output/files",
      #   outputs: [
      #       {preset: "System-Avc_16x9_1080p_29_97fps_8500kbps", modifier: "-1080"},
      #       {preset: "System-Avc_16x9_720p_29_97fps_5000kbps", modifier: "-720"},
      #       {preset: "System-Avc_16x9_540p_29_97fps_3500kbps", modifier: "-540"}
      #     ]
      #   }
      # }
      def create(input_url, options = {})
        input_url = s3_uri(input_url, options)

        input = options[:media_type] == :audio ? make_audio_input(input_url) : make_video_input(input_url)

        create_job_params = {
          queue: queue,
          role: role,
          settings: {
            inputs: [input],
            output_groups: make_output_groups(options)
          }
        }

        response = mediaconvert.create_job(create_job_params)
        job = response.job
        build_encode(job)
      end

      def find(id, _opts = {})
        response = mediaconvert.get_job(id: id)
        job = response.job
        build_encode(job)
      rescue Aws::MediaConvert::Errors::NotFound
        raise ActiveEncode::NotFound, "Job #{id} not found"
      end

      def cancel(id)
        mediaconvert.cancel_job(id: id)
        find(id)
      end

      def log_group
        @log_group ||= "/aws/events/active-encode/mediaconvert/#{queue}"
      end

      def queue
        @queue ||= "Default"
      end

      private

      def build_encode(job)
        return nil if job.nil?
        encode = ActiveEncode::Base.new(job.settings.inputs.first.file_input, {})
        encode.id = job.id
        encode.input.id = job.id
        encode.state = JOB_STATES[job.status]
        encode.current_operations = [job.current_phase].compact
        encode.created_at = job.timing.submit_time
        encode.updated_at = job.timing.finish_time || job.timing.start_time || encode.created_at
        encode.percent_complete = convert_percent_complete(job)
        encode.errors = [job.error_message].compact
        encode.output = []

        encode.input.created_at = encode.created_at
        encode.input.updated_at = encode.updated_at

        encode = complete_encode(encode, job) if encode.state == :completed
        encode
      end

      # Called when job is complete to add output details, will mutate the encode object
      # passed in to add #output details, an array of `ActiveEncode::Output` objects.
      #
      # @param encode [ActiveEncode::Output] encode object to mutate
      # @param job [Aws::MediaConvert::Types::Job] corresponding MediaConvert Job object already looked up
      #
      # @return ActiveEncode::Output the same encode object passed in.
      def complete_encode(encode, job)
        output_result = convert_output(job)
        if output_result.nil?
          raise ResultsNotAvailable.new("Unable to load progress for job #{job.id}", encode) if job.timing.finish_time < 10.minutes.ago
          encode.state = :running
        else
          encode.output = output_result
        end
        encode
      end

      def convert_percent_complete(job)
        case job.status
        when "SUBMITTED"
          0
        when "PROGRESSING"
          job.job_percent_complete
        when "CANCELED", "ERROR"
          50
        when "COMPLETE"
          100
        else
          0
        end
      end

      # extracts and looks up output information from an AWS MediaConvert job.
      # Will also lookup corresponding CloudWatch log entry unless
      # direct_output_lookup config is true.
      #
      # @param job [Aws::MediaConvert::Types::Job]
      #
      # @return [Array<ActiveEncode::Output>,nil]
      def convert_output(job)
        if direct_output_lookup
          build_output_from_only_job(job)
        else
          logged_results = get_encode_results(job)
          return nil if logged_results.nil?
          build_output_from_logged_results(job, logged_results)
        end
      end

      def build_output_from_only_job(job)
        # we need to compile info from two places in job output, two arrays of things,
        # that correspond.
        output_group          = job.dig("settings", "output_groups", 0)
        output_group_settings = output_group.dig("output_group_settings")
        output_settings       = output_group.dig("outputs")

        output_group_details  = job.dig("output_group_details", 0, "output_details")
        file_input_url        = job.dig("settings", "inputs", 0, "file_input")

        outputs = output_group_details.map.with_index do |output_group_detail, index|
          # Right now we only know how to get a URL for hls output, although
          # the others should be possible and very analagous, just not familiar with them.
          if output_group_settings.type == "HLS_GROUP_SETTINGS"
            output_url = MediaConvertOutput.construct_output_url(
              destination: output_group_settings.hls_group_settings.destination,
              file_input_url: file_input_url,
              name_modifier: output_settings[index].name_modifier,
              file_suffix: "m3u8"
            )
          end

          tech_md = MediaConvertOutput.tech_metadata_from_settings(
            output_url: output_url,
            output_settings: output_settings[index],
            output_detail_settings: output_group_detail
          )

          output = ActiveEncode::Output.new

          output.created_at = job.timing.submit_time
          output.updated_at = job.timing.finish_time || job.timing.start_time || output.created_at

          [:width, :height, :frame_rate, :duration, :checksum, :audio_codec, :video_codec,
           :audio_bitrate, :video_bitrate, :file_size, :label, :url, :id].each do |field|
            output.send("#{field}=", tech_md[field])
          end
          output.id ||= "#{job.id}-output#{tech_md[:suffix]}"
          output
        end

        # For HLS, we need to add on the single master adaptive playlist URL, which
        # we can predict what it will be. At the moment, we don't know what to do
        # for other types.
        if output_group_settings.type == "HLS_GROUP_SETTINGS"
          adaptive_playlist_url = MediaConvertOutput.construct_output_url(
            destination: output_group_settings.hls_group_settings.destination,
            file_input_url: file_input_url,
            name_modifier: nil,
            file_suffix: "m3u8"
          )

          output = ActiveEncode::Output.new
          output.created_at = job.timing.submit_time
          output.updated_at = job.timing.finish_time || job.timing.start_time || output.created_at
          output.id = "#{job.id}-output-auto"

          [:duration, :audio_codec, :video_codec].each do |field|
            output.send("#{field}=", outputs.first.send(field))
          end
          output.label = File.basename(adaptive_playlist_url)
          output.url = adaptive_playlist_url
          outputs << output
        end

        outputs
      end

      # Takes an AWS MediaConvert job object, and the fetched CloudWatch log results
      # of MediaConvert completion event, and builds and returns ActiveEncode output
      # from extracted data.
      #
      # @param job [Aws::MediaConvert::Types::Job]
      # @param results [Hash] relevant AWS MediaConvert completion event, fetched from CloudWatch.
      #
      # @return [Array<ActiveEncode::Output>,nil]
      def build_output_from_logged_results(job, logged_results)
        output_settings = job.settings.output_groups.first.outputs

        outputs = logged_results.dig('detail', 'outputGroupDetails', 0, 'outputDetails').map.with_index do |logged_detail, index|
          tech_md = MediaConvertOutput.tech_metadata_from_logged(output_settings[index], logged_detail)
          output = ActiveEncode::Output.new

          output.created_at = job.timing.submit_time
          output.updated_at = job.timing.finish_time || job.timing.start_time || output.created_at

          [:width, :height, :frame_rate, :duration, :checksum, :audio_codec, :video_codec,
           :audio_bitrate, :video_bitrate, :file_size, :label, :url, :id].each do |field|
            output.send("#{field}=", tech_md[field])
          end
          output.id ||= "#{job.id}-output#{tech_md[:suffix]}"
          output
        end

        adaptive_playlist = logged_results.dig('detail', 'outputGroupDetails', 0, 'playlistFilePaths', 0)
        unless adaptive_playlist.nil?
          output = ActiveEncode::Output.new
          output.created_at = job.timing.submit_time
          output.updated_at = job.timing.finish_time || job.timing.start_time || output.created_at
          output.id = "#{job.id}-output-auto"

          [:duration, :audio_codec, :video_codec].each do |field|
            output.send("#{field}=", outputs.first.send(field))
          end
          output.label = File.basename(adaptive_playlist)
          output.url = adaptive_playlist
          outputs << output
        end
        outputs
      end

      # gets complete notification data from CloudWatch logs, returns the CloudWatch
      # log value as a parsed hash.
      #
      # @return [Hash] parsed AWS Cloudwatch data from MediaConvert COMPLETE event.
      def get_encode_results(job)
        start_time = job.timing.submit_time
        end_time = (job.timing.finish_time || Time.now.utc) + 10.minutes

        response = cloudwatch_logs.start_query(
          log_group_name: log_group,
          start_time: start_time.to_i,
          end_time: end_time.to_i,
          limit: 1,
          query_string: "fields @message | filter detail.jobId = '#{job.id}' | filter detail.status = 'COMPLETE' | sort @ingestionTime desc"
        )
        query_id = response.query_id
        response = cloudwatch_logs.get_query_results(query_id: query_id)
        until response.status == "Complete"
          sleep(0.5)
          response = cloudwatch_logs.get_query_results(query_id: query_id)
        end

        return nil if response.results.empty?

        JSON.parse(response.results.first.first.value)
      end

      def cloudwatch_events
        @cloudwatch_events ||= Aws::CloudWatchEvents::Client.new
      end

      def cloudwatch_logs
        @cloudwatch_logs ||= Aws::CloudWatchLogs::Client.new
      end

      def mediaconvert
        @mediaconvert ||= begin
          endpoint = Aws::MediaConvert::Client.new.describe_endpoints.endpoints.first.url
          Aws::MediaConvert::Client.new(endpoint: endpoint)
        end
      end

      def s3_uri(url, options = {})
        bucket = options[:masterfile_bucket]

        case Addressable::URI.parse(url).scheme
        when nil, 'file'
          upload_to_s3 url, bucket
        when 's3'
          return url if options[:use_original_url]
          check_s3_bucket url, bucket
        else
          raise ArgumentError, "Cannot handle source URL: #{url}"
        end
      end

      def check_s3_bucket(input_url, source_bucket)
        # logger.info("Checking `#{input_url}'")
        s3_object = FileLocator::S3File.new(input_url).object
        if s3_object.bucket_name == source_bucket
          # logger.info("Already in bucket `#{source_bucket}'")
          s3_object.key
        else
          s3_key = File.join(SecureRandom.uuid, s3_object.key)
          # logger.info("Copying to `#{source_bucket}/#{input_url}'")
          target = Aws::S3::Object.new(bucket_name: source_bucket, key: input_url)
          target.copy_from(s3_object, multipart_copy: s3_object.size > 15_728_640) # 15.megabytes
          s3_key
        end
      end

      def upload_to_s3(input_url, source_bucket)
        # original_input = input_url
        bucket = Aws::S3::Resource.new(client: s3client).bucket(source_bucket)
        filename = FileLocator.new(input_url).location
        s3_key = File.join(SecureRandom.uuid, File.basename(filename))
        # logger.info("Copying `#{original_input}' to `#{source_bucket}/#{input_url}'")
        obj = bucket.object(s3_key)
        obj.upload_file filename

        s3_key
      end

      def event_rule_exists?(rule_name)
        rule = cloudwatch_events.list_rules(name_prefix: rule_name).rules.find do |existing_rule|
          existing_rule.name == rule_name
        end
        !rule.nil?
      end

      def find_log_group(name)
        cloudwatch_logs.describe_log_groups(log_group_name_prefix: name).log_groups.find do |group|
          group.log_group_name == name
        end
      end

      def create_log_group(name)
        result = find_log_group(name)

        return result unless result.nil?

        cloudwatch_logs.create_log_group(log_group_name: name)
        cloudwatch_logs.put_retention_policy(
          log_group_name: name,
          retention_in_days: SETUP_LOG_GROUP_RETENTION_DAYS
        )

        find_log_group(name)
      end

      def make_audio_input(input_url)
        {
          audio_selectors: { "Audio Selector 1" => { default_selection: "DEFAULT" } },
          audio_selector_groups: {
            "Audio Selector Group 1" => {
              audio_selector_names: ["Audio Selector 1"]
            }
          },
          file_input: input_url,
          timecode_source: "ZEROBASED"
        }
      end

      def make_video_input(input_url)
        {
          audio_selectors: { "Audio Selector 1" => { default_selection: "DEFAULT" } },
          file_input: input_url,
          timecode_source: "ZEROBASED",
          video_selector: {}
        }
      end

      def make_output_groups(options)
        output_type = options[:output_type] || :hls
        raise ArgumentError, "Unknown output type: #{output_type.inspect}" unless OUTPUT_GROUP_TEMPLATES.keys.include?(output_type)
        output_group_settings_key = "#{output_type}_group_settings".to_sym

        destination = options[:destination] || "s3://#{output_bucket}/#{options[:output_prefix]}"
        output_group_settings = OUTPUT_GROUP_TEMPLATES[output_type].merge(destination: destination)

        outputs = options[:outputs].map do |output|
          {
            preset: output[:preset],
            name_modifier: output[:modifier]
          }
        end

        [{
          output_group_settings: {
            type: output_group_settings_key.upcase,
            output_group_settings_key => output_group_settings
          },
          outputs: outputs
        }]
      end
    end
  end
end
