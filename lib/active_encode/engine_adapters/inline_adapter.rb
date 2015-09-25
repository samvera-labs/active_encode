module ActiveEncode
  module EngineAdapters
    class InlineAdapter
      class_attribute :encodes, instance_accessor: false, instance_predicate: false
      InlineAdapter.encodes ||= {}

      def create(encode)
        encode.id = SecureRandom.uuid
        self.class.encodes[encode.id] = encode
        # start encode
        encode.state = :running
        encode
      end

      def find(id, _opts = {})
        self.class.encodes[id]
      end

      def list(*_filters)
        fail NotImplementedError
      end

      def cancel(encode)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.state = :cancelled
        # cancel encode
        inline_encode
      end

      def purge(encode)
        self.class.encodes.delete encode.id
      end

      def remove_output(encode, output_id)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.output.delete(inline_encode.output.find { |o| o[:id] == output_id })
      end
    end
  end
end
