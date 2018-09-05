module ActiveEncode
  module EngineAdapters
    class ActiveJobAdapter
      def initialize
        ActiveSupport::Deprecation.warn("The ActiveJobAdapter is deprecated and will be removed in ActiveEncode 0.3.")
      end

      def create(_input_url, _options) end

      def find(_id) end

      def list(*_filters) end

      def cancel(_id end

      def purge(_encode) end

      def remove_output(_encode, _output_id) end
    end
  end
end
