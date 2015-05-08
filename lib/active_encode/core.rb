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
      def default_options(input)
        {}
      end

      def create(input, options = nil)
        object = new(input, options)
        object.create!
      end 

      def find(id)
        engine_adapter.find(id, cast: self)
      end

      def list(*filters)
        engine_adapter.list(filters)
      end
    end

    def initialize(input, options = nil)
      @input = input
      @options = options || self.class.default_options(input)
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
    end

    def purge!
      run_callbacks :purge do
        self.class.engine_adapter.purge self
      end
    end

    def reload
      fresh_encode = self.class.engine_adapter.find(id, cast: self.class)
      @id = fresh_encode.id
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
