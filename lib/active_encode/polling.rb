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

      define_model_callbacks :status_update, :error, :cancelled, :complete, only: :after

      after_create do |encode|
        ActiveEncode::PollingJob.set(wait: POLLING_WAIT_TIME).perform_later(encode)
      end
    end
  end
end
