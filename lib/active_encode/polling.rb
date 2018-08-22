require 'active_support'
require 'active_support/callbacks'

module ActiveEncode
  module Polling
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    POLLING_WAIT_TIME = 10

    after_create do
      PollingJob.perform_later(self, wait: POLLING_WAIT_TIME)
    end

    included do
      define_callbacks :status_update
      define_callbacks :error
      define_callbacks :cancelled
      define_callbacks :complete
    end
  end
end
