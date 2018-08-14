module ActiveEncode
  module EngineAdapters
    class ActiveJobAdapter
      def initialize
        ActiveSupport::Deprecation.warn("The ActiveJobAdapter is deprecated and will be removed in ActiveEncode 0.3.")
      end

      def create(_encode) end

      def find(_id, _opts = {}) end

      def list(*_filters) end

      def cancel(_encode) end

      def purge(_encode) end

      def remove_output(_encode, _output_id) end
    end
  end
end
