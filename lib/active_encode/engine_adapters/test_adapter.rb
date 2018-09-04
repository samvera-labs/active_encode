module ActiveEncode
  module EngineAdapters
    class TestAdapter
      def initialize
        @encodes = {}
      end

      def create(encode)
        new_encode = ActiveEncode::Base.new(nil).send(:merge!, encode.dup)
        new_encode.id = SecureRandom.uuid
        new_encode.state = :running
        new_encode.created_at = Time.now
        new_encode.updated_at = Time.now
        @encodes[new_encode.id] = new_encode
        new_encode
      end

      def find(id, _opts = {})
        new_encode = @encodes[id].dup
        # Update the updated_at time to simulate changes
        new_encode.updated_at = Time.now
        @encodes[id] = new_encode
        new_encode
      end

      def cancel(encode)
        new_encode = @encodes[encode.id].dup
        new_encode.state = :cancelled
        new_encode.updated_at = Time.now
        @encodes[encode.id] = new_encode
        new_encode
      end

      def list(*_filters)
        raise NotImplementedError
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
