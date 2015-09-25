module ActiveEncode
  module EngineAdapters
    class TestAdapter
      def initialize
        @encodes = {}
      end

      def create(encode)
        encode.id = SecureRandom.uuid
        @encodes[encode.id] = encode
        encode.state = :running
        encode
      end

      def find(id, _opts = {})
        @encodes[id]
      end

      def list(*_filters)
        fail NotImplementedError
      end

      def cancel(encode)
        e = @encodes[encode.id]
        e.state = :cancelled
        e
      end

      def purge(encode)
        @encodes.delete(encode.id)
      end

      def remove_output(_encode, _output_id)
        fail NotImplementedError
      end
    end
  end
end
