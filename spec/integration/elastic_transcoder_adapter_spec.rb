require 'spec_helper'
require 'aws-sdk'
require 'json'
require 'shared_specs/engine_adapter_specs'

describe ActiveEncode::EngineAdapters::ElasticTranscoderAdapter do
  before(:all) do
    ActiveEncode::Base.engine_adapter = :elastic_transcoder
  end
  after(:all) do
    ActiveEncode::Base.engine_adapter = :inline
  end

  let(:client) { double(Aws::ElasticTranscoder::Client) }

  before do
    allow_any_instance_of(ActiveEncode::EngineAdapters::ElasticTranscoderAdapter).to receive(:client).and_return(client)
    allow(client).to receive(:read_job).and_return(Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: job))
    allow(client).to receive(:create_job).and_return(Aws::ElasticTranscoder::Types::CreateJobResponse.new(job: job_created))
  end

  let(:job_created) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_created.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_submitted.json')))]
    j
  end

  it_behaves_like "an ActiveEncode::EngineAdapter"

  describe "#create" do
    let(:job) { job_created }
    let(:create_output) { [{id: "2", url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", hls_url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a.m3u8", label: "hls0400k", segment_duration: "2.0"}] }

    subject { ActiveEncode::Base.create(
      "somefile.mp4",
      pipeline_id: "1471963629141-kmcocm",
        output_key_prefix: "elastic-transcoder-samples/output/hls/",
        outputs: [{
          key: 'hls0400k/' + "e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a",
          preset_id: "1351620000001-200050",
          segment_duration: "2"
        }])
    }

    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.not_to be_empty }
    it { is_expected.to be_running }
    its(:output) { is_expected.to eq create_output }
    its(:current_operations) { is_expected.to be_empty }
    its(:percent_complete) { is_expected.to eq 10 }
    its(:errors) { is_expected.to be_empty }
    its(:created_at) { is_expected.to be_the_same_time_as '2016-08-23T10:47:09-04:00' }
    its(:updated_at) { is_expected.to be_nil }
    its(:finished_at) { is_expected.to be_nil }
    its(:tech_metadata) { is_expected.to be_empty }
  end

  describe "#find" do
    context "a running encode" do
      let(:job) do
        j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_progressing.json'))
        j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_progressing.json')))
        j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_progressing.json')))]
        j
      end

      let(:running_output) { [{id: "2", url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", hls_url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a.m3u8", label: "hls0400k", :segment_duration=>"2.0"}] }
      let(:running_tech_metadata) { {:width=>1280, :height=>720, :video_framerate=>"25", :file_size=>21069678, :duration=>"117312"} }

      subject { ActiveEncode::Base.find('1471963629141-kmcocm') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq '1471963629141-kmcocm' }
      it { is_expected.to be_running }
      its(:output) { is_expected.to eq running_output }
      its(:current_operations) { is_expected.to be_empty }
      its(:percent_complete) { is_expected.to eq 50 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_the_same_time_as '2016-08-23T10:47:09-04:00' }
      its(:updated_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:29-04:00' }
      its(:finished_at) { is_expected.to be_nil }
      its(:tech_metadata) { is_expected.to eq running_tech_metadata }
    end

    context "a canceled encode" do
      let(:job) do
        j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_canceled.json'))
        j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
        j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_canceled.json')))]
        j
      end

      subject { ActiveEncode::Base.find('1471963629141-kmcocm') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq '1471963629141-kmcocm' }
      it { is_expected.to be_cancelled }
      its(:current_operations) { is_expected.to be_empty }
      its(:percent_complete) { is_expected.to eq 0 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_the_same_time_as '2016-08-23T10:47:09-04:00' }
      its(:updated_at) { is_expected.to be_nil }
      its(:finished_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:45-04:00' }
      its(:tech_metadata) { is_expected.to be_empty }
    end

    context "a completed encode" do
      let(:job) do
        j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_completed.json'))
        j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_completed.json')))
        j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_completed.json')))]
        j
      end
      let(:completed_output) { [{id: "2", url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", hls_url: "elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a.m3u8", label: "hls0400k", :width=>400, :height=>224, :video_framerate=>"25", :file_size=>6901104, :duration=>"117353", :segment_duration=> "2.0"}] }
      let(:completed_tech_metadata) { {:width=>1280, :height=>720, :video_framerate=>"25", :file_size=>21069678, :duration=>"117312"} }

      subject { ActiveEncode::Base.find('1471963629141-kmcocm') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq '1471963629141-kmcocm' }
      it { is_expected.to be_completed }
      its(:output) { is_expected.to eq completed_output }
      its(:current_operations) { is_expected.to be_empty }
      its(:percent_complete) { is_expected.to eq 100 }
      its(:errors) { is_expected.to be_empty }
      its(:created_at) { is_expected.to be_the_same_time_as '2016-08-23T10:47:09-04:00' }
      its(:updated_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:29-04:00' }
      its(:finished_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:45-04:00' }
      its(:tech_metadata) { is_expected.to eq completed_tech_metadata }
    end

    context "a failed encode" do
      let(:job) do
        j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_failed.json'))
        j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
        j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_failed.json')))]
        j
      end
      let(:failed_tech_metadata) { {} }

      subject { ActiveEncode::Base.find('1471963629141-kmcocm') }
      it { is_expected.to be_a ActiveEncode::Base }
      its(:id) { is_expected.to eq '1471963629141-kmcocm' }
      it { is_expected.to be_failed }
      its(:current_operations) { is_expected.to be_empty }
      its(:percent_complete) { is_expected.to eq 0 }
      its(:errors) { is_expected.not_to be_empty }
      its(:created_at) { is_expected.to be_the_same_time_as '2016-08-23T10:47:09-04:00' }
      its(:updated_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:29-04:00' }
      its(:finished_at) { is_expected.to be_the_same_time_as '2016-08-23T13:59:45-04:00' }
      its(:tech_metadata) { is_expected.to be_empty }
    end
  end

  describe "#cancel!" do
    before do
      allow(client).to receive(:cancel_job).and_return(cancel_response)
    end

    let(:cancel_response) do
      res = double(Aws::ElasticTranscoder::Types::CancelJobResponse)
      allow(res).to receive(:successful?).and_return(true)
      res
    end

    let(:job) do
      j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_canceled.json'))
      j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
      j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_canceled.json')))]
      j
    end

    let(:encode) { ActiveEncode::Base.create(
      "somefile.mp4",
      pipeline_id: "1471963629141-kmcocm",
        output_key_prefix: "elastic-transcoder-samples/output/hls/",
        outputs: [{
          key: 'hls0400k/' + "e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a",
          preset_id: "1351620000001-200050",
          segment_duration: "2"
        }]) }
    subject { encode.cancel! }
    it { is_expected.to be_a ActiveEncode::Base }
    its(:id) { is_expected.to eq '1471963629141-kmcocm' }
    it { is_expected.to be_cancelled }
  end

  # describe "reload" do
  #   before do
  #     allow(ElasticTranscoder::Job).to receive(:details).and_return(details_response)
  #     allow(ElasticTranscoder::Job).to receive(:progress).and_return(progress_response)
  #   end
  #
  #   let(:details_response) { ElasticTranscoder::Response.new(body: JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_details_running.json'))) }
  #   let(:progress_response) { ElasticTranscoder::Response.new(body: JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_progress_running.json'))) }
  #   let(:reload_output) { [{ id: "510582971", url: "https://elastic_transcoder-temp-storage-us-east-1.s3.amazonaws.com/o/20150609/48a6907086c012f68b9ca43461280515/1726d7ec3e24f2171bd07b2abb807b6c.mp4?AWSAccessKeyId=AKIAI456JQ76GBU7FECA&Signature=vSvlxU94wlQLEbpG3Zs8ibp4MoY%3D&Expires=1433953106", label: nil }] }
  #   let(:reload_tech_metadata) { { audio_bitrate: "52", audio_codec: "aac", audio_channels: "2", duration: "57992", mime_type: "mpeg4", video_framerate: "29.97", height: "240", video_bitrate: "535", video_codec: "h264", width: "320" } }
  #
  #   subject { ActiveEncode::Base.find('166019107').reload }
  #   it { is_expected.to be_a ActiveEncode::Base }
  #   its(:id) { is_expected.to eq '166019107' }
  #   it { is_expected.to be_running }
  #   its(:output) { is_expected.to eq reload_output }
  #   its(:current_operations) { is_expected.to be_empty }
  #   its(:percent_complete) { is_expected.to eq 30.0 }
  #   its(:errors) { is_expected.to be_empty }
  #   its(:created_at) { is_expected.to eq '2015-06-09T16:18:26Z' }
  #   its(:updated_at) { is_expected.to eq '2015-06-09T16:18:28Z' }
  #   its(:finished_at) { is_expected.to be_nil }
  #   its(:tech_metadata) { is_expected.to eq reload_tech_metadata }
  # end
end
