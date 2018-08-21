require 'active_support'
require 'active_encode/callbacks'

module ActiveEncode
  module Core
    extend ActiveSupport::Concern

    included do
      # Encode Identifier
      attr_accessor :id

      # Encode input
      attr_accessor :input

      # Encode output(s)
      attr_accessor :output

      # Encode options
      attr_accessor :options
    end

    module ClassMethods
      def default_options(_input)
        {}
      end

      def create(input, options = nil)
        object = new(input, options)
        object.create!
      end

      def find(id)
        raise ArgumentError, 'id cannot be nil' unless id
        engine_adapter.find(id, cast: self)
      end

      def list(*args)
        ActiveSupport::Deprecation.warn("#list will be removed without replacement in ActiveEncode 0.3")
        engine_adapter.list(args)
      end
    end

    def initialize(input, options = nil)
      @input = input
      @options = options || self.class.default_options(input)
    end

    def create!
      run_callbacks :create do
        merge!(self.class.engine_adapter.create(self))
      end
    end

    def cancel!
      run_callbacks :cancel do
        merge!(self.class.engine_adapter.cancel(self))
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
      merge!(self.class.engine_adapter.find(id, cast: self.class))
    end

    private

      def merge!(encode)
        @id = encode.id
        @input = encode.input
        @output = encode.output
        @state = encode.state
        @current_operations = encode.current_operations
        @errors = encode.errors
        @tech_metadata = encode.tech_metadata
        @created_at = encode.created_at
        @finished_at = encode.finished_at
        @updated_at = encode.updated_at
        @options = encode.options
        @percent_complete = encode.percent_complete

        self
      end
  end
end
