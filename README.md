# ActiveEncode

This gem serves as the basis for the interface between a Ruby (Rails) application and a provider of transcoding services such as [Opencast Matterhorn](http://opencast.org), [Zencoder](http://zencoder.com), [Amazon Elastic Transcoder](http://aws.amazon.com/elastictranscoder/), and [Kaltura](http://www.kaltura.org/).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active-encode'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active-encode

## Usage

Set the engine adapter (default: inline), configure it (if neccessary), then submit encoding jobs!

```ruby
ActiveEncode::Base.engine_adapter = :matterhorn
ActiveEncode::Base.create(File.open('spec/fixtures/Bars_512kb.mp4'))
```
Create returns an encoding job that has been submitted to the encoding engine for processing.  At this point it will have an id, a state, the input, and any additional information the encoding engine returns.

```ruby
#<ActiveEncode::Base:0x00000003f3cd90 @input="http://localhost:8080/files/mediapackage/edcac316-1f98-44b1-88ca-0ce6f80aebc0/ff43c56f-7b8f-4d9c-a846-6e51de2e8cb4/Bars_512kb.mp4", @options={:preset=>"avalon", :stream_base=>"file:///home/cjcolvar/Code/avalon/avalon/red5/webapps/avalon/streams"}, @id="12154", @state=:running, @current_operations=[], @percent_complete=0.0, @output=[], @errors=[], @tech_metadata={}> 
```
```ruby
encode.id  # "12103"
encode.state  # :running
```

This encode can be looked back up later using #find.  Alternatively, use #reload to refresh an instance with the latest information from the 

```ruby
encode = ActiveEncode::Base.find("12103")
encode.reload
```

Progress of a running encode is shown with a current operation (multiple possible if outputs are generated in parallel) and percent complete.  Technical metadata about the input file is added by the encoding engine.  This should include a mime type, checksum, duration, and basic technical details of the audio and video content of the file (codec, audio channels, bitrate, framerate, and dimensions).  Outputs are added once they are created and should include the same technical metadata along with an id, label, and url.

If the encoding job should be stopped, call cancel:

```ruby
encode.cancel!
encode.cancelled?  # true
```

If the encoding job should be deleted, call purge:
```ruby
encode.purge!
```

Purge will attempt to remove all outputs that have been generated.  It is also possible to remove only a single output using its id:

```ruby
encode.remove_output! 'track-9'
```

An encoding job is meant to be the record of the work of the encoding engine and not the current state of the outputs.  Therefore removing outputs will not be reflected in the encoding job.

### Custom jobs

Subclass ActiveEncode::Base to add custom callbacks or default options.  Available callbacks are before, after, and around the create, cancel, and purge actions.

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

Engine adapters are shims between ActiveEncode and the back end encoding service.  Each service has its own API and idiosyncracies so consult the table below to see what features are supported by each adapter.  Add an additional engines by creating an engine adapter class that implements :create, :find, :list, :cancel, :purge, and :remove_output.

| Feature | Matterhorn Adapter | Zencoder Adapter (prototype) | Inline Adapter (In progress) | Test Adapter |
| --- | --- | --- | --- | --- |
| Create | X | X | X | X |
| Find | X | X | X	| X	|
| List	| |	| | |
| Cancel | X | X | | X |
| Purge	| X	| | | X	|
| Remove output	| X	| | | |
| Preset | X | | | |
| Multiple outputs | X (via preset)	| |	| |


## Contributing

1. Fork it ( https://github.com/[my-github-username]/active-encode/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
