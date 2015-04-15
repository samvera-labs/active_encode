require 'active_support'
require 'active_encode/callbacks'

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
    end

    module ClassMethods
      def default_options
        {}
      end

      def default_output
        {}
      end

      def create(input, output = default_output, options = default_options)
        object = new(input, output, options)
        object.create!
        object
      end 

      def find(encode_id)
        engine_adapter.find(encode_id)
      end

      def list(*filters)
        engine_adapter.list(filters)
      end
    end

    def initialize(input, output = default_output, options = default_options)
      @input = input
      @output = output
      @options = options
    end

    def create!
      run_callbacks :create do
        self.class.engine_adapter.create self
      end
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
      fresh_encode = self.class.engine_adapter.find encode_id
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
