require 'spec_helper'
require 'shared_specs/engine_adapter_specs'

describe ActiveEncode::EngineAdapters::FfmpegAdapter do
  around(:example) do |example|
    ActiveEncode::Base.engine_adapter = :ffmpeg
    example.run
    ActiveEncode::Base.engine_adapter = :test
  end

  let(:file) { "file://#{File.absolute_path('spec/fixtures/Bars_512kb.mp4')}" }
  let(:created_job) { ActiveEncode::Base.create(file) }
  let(:running_job) { ActiveEncode::Base.find('running-id') }
  let(:canceled_job) { ActiveEncode::Base.find('cancelled-id') }
  let(:cancelling_job) { ActiveEncode::Base.find('running-id')}
  let(:completed_job) { ActiveEncode::Base.find('completed-id') }
  let(:failed_job) { ActiveEncode::Base.find('failed-id') }

  it_behaves_like "an ActiveEncode::EngineAdapter"
end
