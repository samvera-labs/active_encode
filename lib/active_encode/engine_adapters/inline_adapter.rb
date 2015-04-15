module ActiveEncode
  module EngineAdapters
    class InlineAdapter
      class_attribute :encodes, instance_accessor: false, instance_predicate: false
      InlineAdapter.encodes ||= {}

      def create(encode)
        encode.id = SecureRandom.uuid
        self.class.encodes[encode.id] = encode
        #start encode
        encode.state = :running
      end

      def find(id)
        self.class.encodes[id]
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
        self.class.encodes.delete encode.id
      end
    end
  end
end
