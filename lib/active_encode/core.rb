require 'active_support'
require 'active_encode/callbacks'

module ActiveEncode
  module Core
    extend ActiveSupport::Concern

    included do
      # Encode Identifier
      attr_accessor :id

      # Encode input
      # @return ActiveEncode::Input
      attr_accessor :input

      # Encode output(s)
      # @return Array[ActiveEncode::Output]
      attr_accessor :output

      # Encode options
      attr_accessor :options

      attr_accessor :current_operations
      attr_accessor :percent_complete

      # @deprecated
      attr_accessor :tech_metadata
    end

    module ClassMethods
      def default_options(_input_url)
        {}
      end

      def create(input_url, options = {})
        object = new(input_url, options)
        object.create!
      end

      def find(id)
        raise ArgumentError, 'id cannot be nil' unless id
        encode = new(nil)
        encode.run_callbacks :find do
          encode.send(:merge!, engine_adapter.find(id))
        end
      end

      def list(*args)
        ActiveSupport::Deprecation.warn("#list will be removed without replacement in ActiveEncode 0.3")
        engine_adapter.list(args)
      end
    end

    def initialize(input_url, options = nil)
      @input = Input.new.tap{ |input| input.url = input_url }
      @options = options || self.class.default_options(input_url)
    end

    def create!
      # TODO: Raise ArgumentError if self has an id?
      run_callbacks :create do
        merge!(self.class.engine_adapter.create(self.input.url, self.options))
      end
    end

    def cancel!
      run_callbacks :cancel do
        merge!(self.class.engine_adapter.cancel(self.id))
      end
    end

    def purge!
      ActiveSupport::Deprecation.warn("#purge! will be removed without replacement in ActiveEncode 0.3")
      run_callbacks :purge do
        self.class.engine_adapter.purge self
      end
    end

    def remove_output!(output_id)
      ActiveSupport::Deprecation.warn("#remove_output will be removed without replacement in ActiveEncode 0.3")
      self.class.engine_adapter.remove_output self, output_id
    end

    def reload
      run_callbacks :reload do
        merge!(self.class.engine_adapter.find(id))
      end
    end

    def created?
      !id.nil?
    end

    # @deprecated
    def tech_metadata
      metadata = {}
      [:width, :height, :frame_rate, :duration, :file_size,
       :audio_codec, :video_codec, :audio_bitrate, :video_bitrate, :checksum].each do |key|
        metadata[key] = input.send(key)
      end
    end

    protected

      def merge!(encode)
        @id = encode.id
        @input = encode.input
        @output = encode.output
        @options = encode.options
        @state = encode.state
        @errors = encode.errors
        @created_at = encode.created_at
        @updated_at = encode.updated_at
        @current_operations = encode.current_operations
        @percent_complete = encode.percent_complete

        # deprecated
        @tech_metadata = encode.tech_metadata
        @finished_at = encode.finished_at

        self
      end
  end
end
