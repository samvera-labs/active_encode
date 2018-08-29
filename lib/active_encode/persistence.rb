require 'active_support'

module ActiveEncode
  module Persistence
    extend ActiveSupport::Concern

    included do
      after_find do |encode|
        persist(persistence_model_attributes(encode))
      end

      after_create do |encode|
        persist(persistence_model_attributes(encode))
      end

      after_cancel do |encode|
        persist(persistence_model_attributes(encode))
      end

      after_reload do |encode|
        persist(persistence_model_attributes(encode))
      end
    end

    private

      def persist(encode_attributes)
        model = ActiveEncode::EncodeRecord.find_or_initialize_by(global_id: encode_attributes[:global_id])
        model.update(encode_attributes) # Don't fail if persisting doesn't succeed?
      end

      def persistence_model_attributes(encode)
        {
          global_id: encode.to_global_id.to_s,
          state: encode.state,
          adapter: encode.class.engine_adapter.class.name,
          title: encode.input.to_s,
          # FIXME: Need to ensure that these values come through or else validations will fail
          created_at: encode.created_at,
          updated_at: encode.updated_at,
          raw_object: encode.to_json
        }
      end
  end
end
