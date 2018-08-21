module ActiveEncode
  module EngineAdapters
    class TestAdapter
      def initialize
        @encodes = {}
      end

      def create(encode)
        new_encode = encode.dup
        new_encode.id = SecureRandom.uuid
        new_encode.state = :running
        @encodes[new_encode.id] = new_encode
        new_encode
      end

      def find(id, _opts = {})
        @encodes[id].dup
      end

      def list(*_filters)
        raise NotImplementedError
      end

      def cancel(encode)
        new_encode = @encodes[encode.id].dup
        new_encode.state = :cancelled
        @encodes[encode.id] = new_encode
        new_encode
      end

      def purge(encode)
        @encodes.delete(encode.id)
      end

      def remove_output(_encode, _output_id)
        raise NotImplementedError
      end
    end
  end
end
