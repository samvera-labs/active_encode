require 'active-encode'

class PresetOutputs < ActiveEncode::Base
  def default_options(input)
    {preset: 'avalon-skip-transcoding'}
  end
end

PresetOutputs.create(File.open('/path/to/awesome/video.mp4'))

class HLSOnlyOutputs < PresetOutputs
  def default_options(input)
    super.merge({outputs: [:hls_high, :hls_med, :hls_low]})
  end
end

HLSOnlyOutputs.create(File.open('/path/to/awesome/video.mp4'))
