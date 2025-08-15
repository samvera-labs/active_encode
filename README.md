# ActiveEncode

Code: [![Version](https://badge.fury.io/rb/active_encode.png)](http://badge.fury.io/rb/active_encode)
[![Build Status]([![CircleCI](https://dl.circleci.com/status-badge/img/gh/samvera-labs/active_encode/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/samvera-labs/active_encode/tree/main))
[![Coverage Status](https://coveralls.io/repos/github/samvera-labs/active_encode/badge.svg?branch=main)](https://coveralls.io/github/samvera-labs/active_encode?branch=main)

Docs: [![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

Jump in: [![Slack Status](http://slack.samvera.org/badge.svg)](http://slack.samvera.org/)

# What is ActiveEncode?

ActiveEncode serves as the basis for the interface between a Ruby (Rails) application and a provider of encoding services such as [FFmpeg](https://www.ffmpeg.org/), [Amazon Elastic Transcoder](http://aws.amazon.com/elastictranscoder/), [AWS Elemental MediaConvert](https://aws.amazon.com/mediaconvert/), and [Zencoder](http://zencoder.com).

# Help

The Samvera community is here to help. Please see our [support guide](./SUPPORT.md).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_encode'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_encode

## Prerequisites

FFmpeg (tested with version 4+) and mediainfo (version 17.10+) need to be installed to use the FFmpeg engine adapter.

## Usage

Set the engine adapter (default: test), configure it (if neccessary), then submit encoding jobs. The outputs option specifies the output(s) to create in an adapter-specific way, see individual adapter documentation.

```ruby
ActiveEncode::Base.engine_adapter = :ffmpeg
file = "file://#{File.absolute_path "spec/fixtures/fireworks.mp4"}"
ActiveEncode::Base.create(file, { outputs: [{ label: "low", ffmpeg_opt: "-s 640x480", extension: "mp4"}, { label: "high", ffmpeg_opt: "-s 1280x720", extension: "mp4"}] })
```

Create returns an encoding job (which we sometimes call "an encode object") that has been submitted to the adapter for processing.  At this point it will have an id, a state, the input url, and possibly additional adapter-specific metadata.

```ruby
encode.id  # "1e4a907a-ccff-494f-ad70-b1c5072c2465"
encode.state  # :running
encode.input.url
```

At this point the encode is not complete. You can check on status by looking up the encode by id, or by calling #reload on an existing encode object to refresh it:

```ruby
encode = ActiveEncode::Base.find("1e4a907a-ccff-494f-ad70-b1c5072c2465")
# or
encode.reload

encode.percent_complete
encode.status # running, cancelled, failed, completed
encode.errors # array of errors in case of status `failed`
```

Progress of a running encode is shown with current operations (multiple are possible when outputs are generated in parallel) and percent complete.

Technical metadata about the input file may be added by some adapters, and may be available before completion.  This should include a mime type, checksum, duration, and basic technical details of the audio and video content of the file (codec, audio channels, bitrate, frame rate, and dimensions).

```ruby
encode.input.url
encode.input.height
encode.input.width
encode.input.checksum
# etc
```

Outputs are added once they are created and should include the same technical metadata along with an id, label, and url.

```ruby
output = encode.outputs.first
output.url
output.id
output.width
```

If you want to stop the encoding job call cancel:

```ruby
encode.cancel!
encode.cancelled?  # true
```

An encode object is meant to be the record of the work of the encoding engine and not the current state of the outputs.  Therefore moved or deleted outputs will not be reflected in the encode object.

### AWS ElasticTranscoder

To use active_encode with the AWS ElasticTransoder, the following are required:
- An S3 bucket to store master files
- An S3 bucket to store derivatives (recommended to be separate)
- An ElasticTranscoder pipeline
- Some transcoding presets for the pipeline

Set the adapter:

```ruby
ActiveEncode::Base.engine_adapter = :elastic_transcoder
```

Construct the options hash:

```ruby
outputs = [{ key: "quality-low/hls/fireworks", preset_id: '1494429796844-aza6zh', segment_duration: '2' },
           { key: "quality-medium/hls/fireworks", preset_id: '1494429797061-kvg9ki', segment_duration: '2' },
           { key: "quality-high/hls/fireworks", preset_id: '1494429797265-9xi831', segment_duration: '2' }]
options = {pipeline_id: 'my-pipeline-id', masterfile_bucket: 'my-master-files', outputs: outputs}
```

Create the job:

```ruby
file = 'file:///path/to/file/fireworks.mp4' # or 's3://my-bucket/fireworks.mp4'
encode = ActiveEncode::Base.create(file, options)
```

### AWS Elemental MediaCovert

[MediaConvert](https://aws.amazon.com/mediaconvert/) is a newer AWS service than Elastic Transcoder. The MediaConvert adapter works using [output presets]((https://docs.aws.amazon.com/mediaconvert/latest/ug/creating-preset-from-scratch.html)) defined in the MediaConvert service for your account. Some additional dependencies will need to be added to your project, see [Guide](./guides/media_convert_adapter.md).

```ruby
ActiveEncode::Base.engine_adapter = :media_convert
ActiveEncode::Base.engine_adapter.role = 'arn:aws:iam::111111111111:role/name-of-role'
ActiveEncode::Base.engine_adapter.output_bucket = 'name-of-bucket'

# will create CloudWatch/EventBridge resources necessary to capture outputs,
# only needs to be called once although is safe to call redundantly.
ActiveEncode::Base.engine_adapter.setup!

encode = ActiveEncode::Base.create(
  "file://path/to/file.mp4",
  {
    masterfile_bucket: "name-of-my-masterfile_bucket"
    output_prefix: "path/to/output/base_name_of_outputs",
    use_original_url: true,
    outputs: [
      { preset: "my-hls-preset-high", modifier: "_high" },
      { preset: "my-hls-preset-medium", modifier: "_medium" },
      { preset: "my-hls-preset-low", modifier: "_low" },
    ]
  }
)
```

See more details and guidance in our [longer guide](./guides/media_convert_adapter.md), or in comment docs in [adapter class](./lib/active_encode/engine_adapters/media_convert_adapter.rb).


### Custom jobs

Subclass ActiveEncode::Base to add custom callbacks or default options.  Available callbacks are before, after, and around the create and cancel actions.

```ruby
class CustomEncode < ActiveEncode::Base
  after_create do
    logger.info "Created encode with id #{self.reload.id}"
  end

  def self.default_options(input)
    {preset: 'avalon-skip-transcoding'}
  end
end
```

### Engine Adapters

Engine adapters are shims between ActiveEncode and the back end encoding service.  You can add an additional engine by creating an engine adapter class that implements `:create`, `:find`, and `:cancel` and passes the shared specs.

For example:
```ruby
# In your application at:
# lib/active_encode/engine_adapters/my_custom_adapter.rb
module ActiveEncode
  module EngineAdapters
    class MyCustomAdapter
      def create(input_url, options = {})
        # Start a new encoding job. This may be an external service, or a
        # locally queued job.

        # Return an instance ActiveEncode::Base (or subclass) that represents
        # the encoding job that was just started.
      end

      def find(id, opts = {})
        # Find the encoding job for the given parameters.

        # Return an instance of ActiveEncode::Base (or subclass) that represents
        # the found encoding job.
      end

      def cancel(id)
        # Cancel the encoding job for the given id.

        # Return an instance of ActiveEncode::Base (or subclass) that represents
        # the canceled job.
      end
    end
  end
end
```
Then, use the shared specs...
```ruby
# In your application at...
# spec/lib/active_encode/engine_adapters/my_custom_adapter_spec.rb
require 'spec_helper'
require 'active_encode/spec/shared_specs'
RSpec.describe MyCustomAdapter do
  let(:created_job) {
    # an instance of ActiveEncode::Base represented a newly created encode job
  }
  let(:running_job) {
    # an instance of ActiveEncode::Base represented a running encode job
  }
  let(:canceled_job) {
    # an instance of ActiveEncode::Base represented a canceled encode job
  }
  let(:completed_job) {
    # an instance of ActiveEncode::Base represented a completed encode job
  }
  let(:failed_job) {
    # an instance of ActiveEncode::Base represented a failed encode job
  }
  let(:completed_tech_metadata) {
    # a hash representing completed technical metadata
  }
  let(:completed_output) {
    # data representing completed output
  }
  let(:failed_tech_metadata) {
    # a hash representing failed technical metadata
  }

  # Run the shared specs.
  it_behaves_like 'an ActiveEncode::EngineAdapter'
end
```

## Contributing 

If you're working on PR for this project, create a feature branch off of `main`. 

This repository follows the [Samvera Community Code of Conduct](https://samvera.atlassian.net/wiki/spaces/samvera/pages/405212316/Code+of+Conduct) and [language recommendations](https://github.com/samvera/maintenance/blob/main/templates/CONTRIBUTING.md#language).  Please ***do not*** create a branch called `master` for this repository or as part of your pull request; the branch will either need to be removed or renamed before it can be considered for inclusion in the code base and history of this repository.

# Acknowledgments

This software has been developed by and is brought to you by the Samvera community.  Learn more at the
[Samvera website](http://samvera.org/).

![Samvera Logo](https://wiki.duraspace.org/download/thumbnails/87459292/samvera-fall-font2-200w.png?version=1&modificationDate=1498550535816&api=v2)
