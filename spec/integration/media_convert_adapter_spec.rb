# frozen_string_literal: true
require 'spec_helper'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-cloudwatchlogs'
require 'aws-sdk-mediaconvert'
require 'aws-sdk-s3'
require 'json'
require 'active_encode/spec/shared_specs'
require 'active_support/json'
require 'active_support/time'

def with_json_parsing
  old_settings = { parse_json_times: ActiveSupport.parse_json_times, time_zone: Time.zone }
  ActiveSupport.parse_json_times = true
  Time.zone = 'America/Chicago'
  yield
ensure
  ActiveSupport.parse_json_times = old_settings[:parse_json_times]
  Time.zone = old_settings[:time_zone]
end

def reconstitute_response(fixture_path)
  with_json_parsing do
    HashWithIndifferentAccess.new(ActiveSupport::JSON.decode(File.read(File.join("spec/fixtures", fixture_path))))
  end
end

describe ActiveEncode::EngineAdapters::MediaConvertAdapter do
  around do |example|
    # Setting this before each test works around a stubbing + memoization limitation
    ActiveEncode::Base.engine_adapter = :media_convert
    ActiveEncode::Base.engine_adapter.role = 'arn:aws:iam::123456789012:role/service-role/MediaConvert_Default_Role'
    ActiveEncode::Base.engine_adapter.output_bucket = 'output-bucket'
    example.run
    ActiveEncode::Base.engine_adapter = :test
  end

  let(:job_id) { "1625859001514-vvqfwj" }
  let(:mediaconvert) { Aws::MediaConvert::Client.new(stub_responses: true) }
  let(:cloudwatch_events) { Aws::CloudWatchEvents::Client.new(stub_responses: true) }
  let(:cloudwatch_logs) { Aws::CloudWatchLogs::Client.new(stub_responses: true) }

  let(:s3client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    mediaconvert.stub_responses(:describe_endpoints, reconstitute_response("media_convert/endpoints.json"))

    allow(Aws::MediaConvert::Client).to receive(:new).and_return(mediaconvert)
    allow(Aws::CloudWatchEvents::Client).to receive(:new).and_return(cloudwatch_events)
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(cloudwatch_logs)
    allow(Aws::S3::Client).to receive(:new).and_return(s3client)
  end

  let(:created_job) do
    mediaconvert.stub_responses(:create_job, reconstitute_response("media_convert/job_created.json"))

    ActiveEncode::Base.create(
      "s3://input-bucket/test_files/source_file.mp4",
      output_prefix: "active-encode-test/output",
      outputs: [
        { preset: "System-Avc_16x9_1080p_29_97fps_8500kbps", modifier: "-1080" },
        { preset: "System-Avc_16x9_720p_29_97fps_5000kbps", modifier: "-720" },
        { preset: "System-Avc_16x9_540p_29_97fps_3500kbps", modifier: "-540" }
      ],
      use_original_url: true
    )
  end

  let(:running_job) do
    mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_progressing.json"))
    ActiveEncode::Base.find(job_id)
  end

  let(:canceled_job) do
    mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_canceled.json"))
    ActiveEncode::Base.find(job_id)
  end

  let(:cancelling_job) do
    mediaconvert.stub_responses(:cancel_job, reconstitute_response("media_convert/job_canceling.json"))
    mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_canceled.json"))
    ActiveEncode::Base.find(job_id)
  end

  let(:completed_job) do
    mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_completed.json"))
    cloudwatch_logs.stub_responses(:start_query, reconstitute_response("media_convert/job_completed_detail_query.json"))
    cloudwatch_logs.stub_responses(:get_query_results, reconstitute_response("media_convert/job_completed_detail.json"))

    ActiveEncode::Base.find(job_id)
  end

  let(:recent_completed_job_without_results) do
    job_response = reconstitute_response("media_convert/job_completed.json")
    job_response["job"]["timing"]["finish_time"] = 5.minutes.ago
    mediaconvert.stub_responses(:get_job, job_response)
    cloudwatch_logs.stub_responses(:start_query, reconstitute_response("media_convert/job_completed_detail_query.json"))
    cloudwatch_logs.stub_responses(:get_query_results, reconstitute_response("media_convert/job_completed_empty_detail.json"))

    ActiveEncode::Base.find(job_id)
  end

  let(:failed_job) do
    mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_failed.json"))

    ActiveEncode::Base.find(job_id)
  end

  let(:completed_output) do
    [
      { id: "1625859001514-vvqfwj-output-auto", url: "s3://output-bucket/active-encode-test/output.m3u8",
        label: "output.m3u8", audio_codec: "AAC", duration: 888_020, video_codec: "H_264" },
      { id: "1625859001514-vvqfwj-output-1080", url: "s3://output-bucket/active-encode-test/output-1080.m3u8",
        label: "output-1080.m3u8", audio_bitrate: 128_000, audio_codec: "AAC", duration: 888_020,
        video_bitrate: 8_500_000, height: 1080, width: 1920, video_codec: "H_264", frame_rate: 29.97 },
      { id: "1625859001514-vvqfwj-output-720", url: "s3://output-bucket/active-encode-test/output-720.m3u8",
        label: "output-720.m3u8", audio_bitrate: 96_000, audio_codec: "AAC", duration: 888_020,
        video_bitrate: 5_000_000, height: 720, width: 1280, video_codec: "H_264", frame_rate: 29.97 },
      { id: "1625859001514-vvqfwj-output-540", url: "s3://output-bucket/active-encode-test/output-540.m3u8",
        label: "output-540.m3u8", audio_bitrate: 96_000, audio_codec: "AAC", duration: 888_020,
        video_bitrate: 3_500_000, height: 540, width: 960, video_codec: "H_264", frame_rate: 29.97 }
    ]
  end
  let(:completed_tech_metadata) { {} }
  let(:failed_tech_metadata) { {} }

  it_behaves_like "an ActiveEncode::EngineAdapter"

  describe "output location specification" do
    let(:operations) { mediaconvert.api_requests(exclude_presign: true) }
    before do
      mediaconvert.stub_responses(:create_job, reconstitute_response("media_convert/job_created.json"))
    end

    it "can use output_bucket and output_prefix" do
      ActiveEncode::Base.create(
        "s3://input-bucket/test_files/source_file.mp4",
        output_prefix: "active-encode-test/output",
        outputs: [],
        use_original_url: true
      )
      create_job_operation = operations.find { |o| o[:operation_name] == :create_job }
      expect(create_job_operation).to be_present

      destination = create_job_operation.dig(:params, :settings, :output_groups, 0,
        :output_group_settings, :hls_group_settings, :destination)

      expect(destination).to eq("s3://output-bucket/active-encode-test/output")
    end

    it "can use destination arg" do
      ActiveEncode::Base.create(
        "s3://input-bucket/test_files/source_file.mp4",
        destination: "s3://alternate-output-bucket/my-path/output",
        outputs: [],
        use_original_url: true
      )
      create_job_operation = operations.find { |o| o[:operation_name] == :create_job }
      expect(create_job_operation).to be_present

      destination = create_job_operation.dig(:params, :settings, :output_groups, 0,
        :output_group_settings, :hls_group_settings, :destination)

      expect(destination).to eq("s3://alternate-output-bucket/my-path/output")
    end
  end

  describe "output_group_destination_settings" do
    let(:operations) { mediaconvert.api_requests(exclude_presign: true) }
    before do
      mediaconvert.stub_responses(:create_job, reconstitute_response("media_convert/job_created.json"))
    end

    it "are sent to MediaConvert" do
      ActiveEncode::Base.create(
        "s3://input-bucket/test_files/source_file.mp4",
        destination: "s3://alternate-output-bucket/my-path/output",
        outputs: [],
        use_original_url: true,
        output_group_destination_settings: {
          s3_settings: {
            access_control: {
              canned_acl: "PUBLIC_READ"
            }
          }
        }
      )

      create_job_operation = operations.find { |o| o[:operation_name] == :create_job }
      expect(create_job_operation).to be_present

      destination_settings = create_job_operation.dig(:params, :settings, :output_groups, 0,
        :output_group_settings, :hls_group_settings, :destination_settings)
      expect(destination_settings).to eq({ s3_settings: { access_control: { canned_acl: "PUBLIC_READ" } } })
    end
  end

  describe "queue" do
    let(:operations) { mediaconvert.api_requests(exclude_presign: true) }

    it "uses the default queue" do
      mediaconvert.stub_responses(:create_job, reconstitute_response("media_convert/job_created.json"))
      ActiveEncode::Base.create(
        "s3://input-bucket/test_files/source_file.mp4",
        output_prefix: "active-encode-test/output",
        outputs: [],
        use_original_url: true
      )
      expect(operations).to include(include(operation_name: :create_job, params: include(queue: 'Default')))
    end

    it "uses a specific queue" do
      mediaconvert.stub_responses(:create_job, reconstitute_response("media_convert/job_created.json"))
      ActiveEncode::Base.engine_adapter.queue = 'test-queue'
      ActiveEncode::Base.create(
        "s3://input-bucket/test_files/source_file.mp4",
        output_prefix: "active-encode-test/output",
        outputs: [],
        use_original_url: true
      )
      expect(operations).to include(include(operation_name: :create_job, params: include(queue: 'test-queue')))
    end
  end

  describe "output" do
    it "contains all expected outputs" do
      completed_output.each do |expected_output|
        found_output = completed_job.output.find { |output| output.id == expected_output[:id] }
        expected_output.each_pair do |key, value|
          expect(found_output.send(key)).to eq(value)
        end
      end
    end

    it "has no logging entries but finished within the last 10 minutes" do
      expect(recent_completed_job_without_results.state).to eq(:running)
    end

    it "finished more than 10 minutes ago but has no logging entries" do
      mediaconvert.stub_responses(:get_job, reconstitute_response("media_convert/job_completed.json"))
      cloudwatch_logs.stub_responses(:start_query, reconstitute_response("media_convert/job_completed_detail_query.json"))
      cloudwatch_logs.stub_responses(:get_query_results, reconstitute_response("media_convert/job_completed_empty_detail.json"))

      expect { ActiveEncode::Base.find(job_id) }.to raise_error do |error|
        expect(error).to be_a(ActiveEncode::EngineAdapters::MediaConvertAdapter::ResultsNotAvailable)
        expect(error.encode).to be_a(ActiveEncode::Base)
        expect(error.encode.state).to eq(:completed)
      end
    end
  end

  describe "direct_output_lookup" do
    before do
      ActiveEncode::Base.engine_adapter.direct_output_lookup = true
    end

    it "contains all expected outputs" do
      completed_output.each do |expected_output|
        found_output = completed_job.output.find { |output| output.id == expected_output[:id] }
        expected_output.each_pair do |key, value|
          expect(found_output.send(key)).to eq(value)
        end
      end
    end

    it "does not make cloudwatch queries" do
      expect(cloudwatch_logs).not_to receive(:start_query)
      expect(cloudwatch_logs).not_to receive(:get_query_results)

      completed_job
    end
  end

  describe "#s3_uri" do
    context "when filename has no special characters" do
      context "non-s3 file" do
        let(:input_url) { "spec/fixtures/fireworks.mp4" }
        let(:source_bucket) { "bucket1" }

        it "calls the #upload_to_s3 method" do
          allow(SecureRandom).to receive(:uuid).and_return("randomstring")
          expect(described_class.new.send(:s3_uri, input_url, { masterfile_bucket: source_bucket })).to eq "randomstring/fireworks.mp4"
        end
      end
      context "s3 file" do
        let(:input_url) { "s3://bucket1/file.mp4" }
        let(:source_bucket) { "bucket1" }

        it "calls the #check_s3_bucket method" do
          expect(described_class.new.send(:s3_uri, input_url, { masterfile_bucket: source_bucket })).to eq "file.mp4"
        end
      end
    end
    context "when filename has special characters" do
      context "non-s3 file" do
        let(:input) { ["'file_with_single_quote'.mp4", '"file_with_double_quote".mp4', "file with space.mp4", "file.with...periods.mp4", "file.with :=+%sp3c!l-ch4cts().mp4", '@ወዳጅህ ማር ቢ. ሆን ጨርስ. ህ አትላሰ!@#$^^&$%&.mov'] }
        let(:clean) { ["_file_with_single_quote_.mp4", "_file_with_double_quote_.mp4", "file_with_space.mp4", "filewithperiods.mp4", "filewith_____sp3c_l-ch4cts__.mp4", '__________________________________.mov'] }
        let(:source_bucket) { "bucket1" }

        it "calls the #upload_to_s3 method" do
          allow(SecureRandom).to receive(:uuid).and_return("randomstring")
          input.each_with_index do |url, index|
            expect(described_class.new.send(:s3_uri, "spec/fixtures/#{url}", { masterfile_bucket: source_bucket })).to eq "randomstring/#{clean[index]}"
          end
        end
      end
      context "s3 file" do
        let(:input_urls) { ["s3://bucket1/'file_with_single_quote'.mp4", 's3://bucket1/"file_with_double_quote".mp4', "s3://bucket1/file with space.mp4", "s3://bucket1/file.with...periods.mp4", "s3://bucket1/file.with :=+%sp3c!l-ch4cts().mp4", 's3://bucket1/@ወዳጅህ ማር ቢ. ሆን ጨርስ. ህ አትላሰ!@#$^^&$%&.mov'] }
        let(:clean) { ["_file_with_single_quote_.mp4", "_file_with_double_quote_.mp4", "file_with_space.mp4", "filewithperiods.mp4", "filewith_____sp3c_l-ch4cts__.mp4", '__________________________________.mov'] }
        let(:source_bucket) { "bucket2" }

        it "calls the #check_s3_bucket method" do
          allow(SecureRandom).to receive(:uuid).and_return("randomstring")
          input_urls.each_with_index do |url, index|
            expect(described_class.new.send(:s3_uri, url, { masterfile_bucket: source_bucket })).to eq "randomstring/#{clean[index]}"
          end
        end
      end
    end
  end
end
