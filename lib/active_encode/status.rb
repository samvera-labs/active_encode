require 'active_support'

module ActiveEncode
  module Status
    extend ActiveSupport::Concern

    included do
      # Current state of the encoding process
      attr_accessor :state
      attr_accessor :current_operations
      attr_accessor :percent_complete
      attr_accessor :errors

      attr_accessor :created_at
      attr_accessor :finished_at
      attr_accessor :updated_at
    end

    def created?
      !id.nil?
    end

    def cancelled?
      state == :cancelled
    end

    def completed?
      state == :completed
    end

    def running?
      state == :running
    end

    def failed?
      state == :failed
    end
  end
end
