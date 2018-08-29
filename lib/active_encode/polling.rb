require 'active_support'
require 'active_model/callbacks'

module ActiveEncode
  module Polling
    extend ActiveSupport::Concern

    POLLING_WAIT_TIME = 10.seconds.freeze

    CALLBACKS = [
        :after_status_update, :after_error, :after_cancelled, :after_complete
    ].freeze

    included do
      extend ActiveModel::Callbacks

      define_model_callbacks :status_update, only: :after
      define_model_callbacks :error, only: :after
      define_model_callbacks :cancelled, only: :after
      define_model_callbacks :complete, only: :after

      after_create do |encode|
        ActiveEncode::PollingJob.set(wait: POLLING_WAIT_TIME).perform_later(encode)
      end
    end

    # These methods will be included into any Active Encode object, adding
    # callbacks for +create+, +cancel+, and +purge+ methods.
    module ClassMethods
      def after_status_update(*filters, &blk)
        set_callback(:status_update, :after, *filters, &blk)
      end

      def after_error(*filters, &blk)
        set_callback(:error, :after, *filters, &blk)
      end

      def after_cancelled(*filters, &blk)
        set_callback(:cancelled, :after, *filters, &blk)
      end

      def after_complete(*filters, &blk)
        set_callback(:complete, :after, *filters, &blk)
      end
    end
  end
end
