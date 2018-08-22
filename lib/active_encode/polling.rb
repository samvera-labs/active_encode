require 'active_support'
require 'active_support/callbacks'

module ActiveEncode
  module Polling
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    POLLING_WAIT_TIME = 10.seconds.freeze

    included do
      define_callbacks :status_update
      define_callbacks :error
      define_callbacks :cancelled
      define_callbacks :complete

      after_create do |encode|
        PollingJob.perform_later(encode, wait: POLLING_WAIT_TIME)
      end
    end
  end
end
