module ActiveEncode
  module EngineAdapters
    class InlineAdapter
      class_attribute :encodes, instance_accessor: false, instance_predicate: false
      InlineAdapter.encodes ||= {}

      def create(encode)
        encode.encode_id = SecureRandom.uuid
        self.class.encodes[encode.encode_id] = encode
        #start encode
        encode.state = :running
      end

      def find(encode_id)
        self.class.encodes[encode_id]
      end

      def list(*filters)
        raise NotImplementedError
      end

      def cancel(encode)
        encode.state = :cancelled
        #cancel encode
        encode
      end

      def purge(encode)
        self.class.encodes.delete encode.encode_id
      end
    end
  end
end
