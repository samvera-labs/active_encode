module ActiveEncode
  module Core
    extend ActiveSupport::Concern

    included do
      # Encode Identifier
      attr_accessor :encode_id

      # Encode input
      attr_accessor :input

      # Encode output(s)
      attr_accessor :output

      # Encode options
      attr_accessor :options

      attr_reader :state, :current_operations, :errors, :tech_metadata
    end

    module ClassMethods
      def create(input, output, *options)
        run_callbacks :create do
          engine_adapter.create(input, output, options)
        end
      end 

      def find(encode_id)
        engine_adapter.find(encode_id)
      end

      def list(*filters)
        engine_adapter.list(filters)
      end
    end

    def cancelled?
      state == :cancelled
    end

    def completed?
      state == :completed
    end

    def running?
      state == :running
    end

    def cancel!
      run_callbacks :cancel do
        self.class.engine_adapter.cancel self
      end
      self.reload
      self
    end

    def purge!
      run_callbacks :purge do
        self.class.engine_adapter.purge self
      end
      self.reload
      self
    end

    def reload
      fresh_encode = self.class.engine_adapter.find self
      @encode_id = fresh_encode.encode_id
      @input = fresh_encode.input
      @output = fresh_encode.output
      @state = fresh_encode.state
      @current_operations = fresh_encode.current_operations
      @errors = fresh_encode.errors
      @tech_metadata = fresh_encode.tech_metadata

      self
    end
  end
end
