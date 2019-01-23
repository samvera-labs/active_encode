require 'spec_helper'
require 'aws-sdk'
require 'json'
require 'shared_specs/engine_adapter_specs'

describe ActiveEncode::EngineAdapters::ElasticTranscoderAdapter do
  around(:example) do |example|
    # Setting this before each test works around a stubbing + memoization limitation
    ActiveEncode::Base.engine_adapter = :elastic_transcoder
    example.run
    ActiveEncode::Base.engine_adapter = :test
  end

  let(:client) { Aws::ElasticTranscoder::Client.new(stub_responses: true) }
  let(:s3client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    allow(Aws::ElasticTranscoder::Client).to receive(:new).and_return(client)
    allow(Aws::S3::Client).to receive(:new).and_return(s3client)
  end

  let(:created_job) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_created.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_submitted.json')))]

    client.stub_responses(:create_job, Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j))

    ActiveEncode::Base.create(
     "spec/fixtures/fireworks.mp4",
     pipeline_id: "1471963629141-kmcocm",
     masterfile_bucket: "BucketName",
     output_key_prefix: "elastic-transcoder-samples/output/hls/",
     outputs: [{
       key: 'hls0400k/' + "e8fe80f5bsomefilesource_bucket7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a",
       preset_id: "1351620000001-200050",
       segment_duration: "2",
     }])
  end

  let(:running_job) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_progressing.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_progressing.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_progressing.json')))]

    client.stub_responses(:read_job, Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j))
    ActiveEncode::Base.find('running-id')
  end

  let(:canceled_job) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_canceled.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_canceled.json')))]

    client.stub_responses(:read_job, Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j))

    ActiveEncode::Base.find('cancelled-id')
  end

  let(:cancelling_job) do
    j1 = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_progressing.json'))
    j1.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_progressing.json')))
    j1.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_progressing.json')))]

    j2 = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_canceled.json'))
    j2.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
    j2.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_canceled.json')))]

    client.stub_responses(:read_job, [Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j1), Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j2)])

    cancel_response = double(Aws::ElasticTranscoder::Types::CancelJobResponse)
    allow(cancel_response).to receive(:successful?).and_return(true)
    allow(client).to receive(:cancel_job).and_return(cancel_response)

    ActiveEncode::Base.find('cancelled-id')
  end

  let(:completed_job) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_completed.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_completed.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_completed.json')))]

    client.stub_responses(:read_job, Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j))
    ActiveEncode::Base.find('completed-id')
  end

  let(:failed_job) do
    j = Aws::ElasticTranscoder::Types::Job.new JSON.parse(File.read('spec/fixtures/elastic_transcoder/job_failed.json'))
    j.input = Aws::ElasticTranscoder::Types::JobInput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/input_generic.json')))
    j.outputs = [ Aws::ElasticTranscoder::Types::JobOutput.new(JSON.parse(File.read('spec/fixtures/elastic_transcoder/output_failed.json')))]

    client.stub_responses(:read_job, Aws::ElasticTranscoder::Types::ReadJobResponse.new(job: j))
    ActiveEncode::Base.find('failed-id')
  end

  let(:completed_output) { [{ id: "2", url: "s3://BucketName/elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", label: "hls0400k", :width=>400, :height=>224, :frame_rate=>25, :file_size=>6901104, :duration=>117353 }] }
  let(:completed_tech_metadata) { { :width=>1280, :height=>720, :frame_rate=>25, :file_size=>21069678, :duration=>117312 } }
  let(:failed_tech_metadata) { {} }

  it_behaves_like "an ActiveEncode::EngineAdapter"

  describe "#create" do
    let(:create_output) { [{ id: "2", url: "s3://BucketName/elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", label: "hls0400k" }] }

    subject { created_job }

    it { is_expected.to be_running }
    its(:current_operations) { is_expected.to be_empty }

    it 'output has technical metadata' do
      subject.output.each do |output|
        expected_output = create_output.find {|expected_out| expected_out[:id] == output.id }
        expect(output.as_json.symbolize_keys).to include expected_output
      end
    end
  end

  describe "#find" do
    context "a running encode" do
      let(:running_output) { [{ id: "2", url: "s3://BucketName/elastic-transcoder-samples/output/hls/hls0400k/e8fe80f5b7063b12d567b90c0bdf6322116bba11ac458fe9d62921644159fe4a", label: "hls0400k" }] }
      let(:running_tech_metadata) { {:width=>1280, :height=>720, :frame_rate=>25, :file_size=>21069678, :duration=>117312} }

      subject { running_job }

      its(:current_operations) { is_expected.to be_empty }

      it 'input has technical metadata' do
        expect(subject.input.as_json.symbolize_keys).to include running_tech_metadata
      end

      it 'output has technical metadata' do
        subject.output.each do |output|
          expected_output = running_output.find {|expected_out| expected_out[:id] == output.id }
          expect(output.as_json.symbolize_keys).to include expected_output
        end
      end
    end
  end
end
