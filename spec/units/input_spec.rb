require 'spec_helper'

describe ActiveEncode::Input do
  subject { described_class.new }

  describe 'attributes' do
    it { is_expected.to respond_to(:id, :url) }
    it { is_expected.to respond_to(:state, :errors, :created_at, :updated_at) }
    it { is_expected.to respond_to(:width, :height, :frame_rate, :checksum,
                                   :audio_codec, :video_codec, :audio_bitrate, :video_bitrate) }
  end
end
