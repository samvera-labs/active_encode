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

      def find(id, opts = {})
        return @encodes[id]
      end

      def list(*filters)
        raise NotImplementedError
      end

      def cancel(encode)
        e = @encodes[encode.id]
        e.state = :cancelled
        e
      end

      def purge(encode)
        @encodes.delete(encode.id)
      end

      def remove_output(encode, output_id)
        raise NotImplementedError
      end
    end
  end
end
