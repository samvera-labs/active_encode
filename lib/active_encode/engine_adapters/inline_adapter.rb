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
        encode
      end

      def find(id, opts = {})
        self.class.encodes[id]
      end

      def list(*filters)
        raise NotImplementedError
      end

      def cancel(encode)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.state = :cancelled
        #cancel encode
        inline_encode
      end

      def purge(encode)
        self.class.encodes.delete encode.id
      end

      def remove_output(encode, output_id)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.outputs.delete output_id
      end
    end
  end
end
