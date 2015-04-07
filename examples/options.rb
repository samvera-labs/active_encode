require 'hydra-transcoder'

class PresetOutputs < ActiveEncode::Base
  def default_options
    {preset: 'avalon-skip-transcoding'}
  end

  def default_outputs
    {:hls_high, :hls_med, :hls_low, :rtmp_high, :rtmp_med, :rtmp_low}
  end
end

PresetOutputs.create(File.open('/path/to/awesome/video.mp4'))

class HLSOnlyOutputs < PresetOutputs
  def default_outputs
    {:hls_high, :hls_med, :hls_low}
  end
end

HLSOnlyOutputs.create(File.open('/path/to/awesome/video.mp4'))
