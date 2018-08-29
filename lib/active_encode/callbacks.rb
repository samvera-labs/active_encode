require 'active_model/callbacks'

module ActiveEncode
  # = Active Encode Callbacks
  #
  # Active Encode provides hooks during the life cycle of an encode. Callbacks allow you
  # to trigger logic during the life cycle of an encode. Available callbacks are:
  #
  # * <tt>after_find</tt>
  # * <tt>after_reload</tt>
  # * <tt>before_create</tt>
  # * <tt>around_create</tt>
  # * <tt>after_create</tt>
  # * <tt>before_cancel</tt>
  # * <tt>around_cancel</tt>
  # * <tt>after_cancel</tt>
  # * <tt>before_purge</tt>
  # * <tt>around_purge</tt>
  # * <tt>after_purge</tt>
  #
  module Callbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :after_find, :after_reload, :before_create, :around_create,
      :after_create, :before_cancel, :around_cancel, :after_cancel,
      :before_purge, :around_purge, :after_purge
    ].freeze

    included do
      extend ActiveModel::Callbacks

      define_model_callbacks :find, :reload, only: :after
      define_model_callbacks :create, :cancel, :purge

      def self.before_purge(*filters, &blk)
        ActiveSupport::Deprecation.warn("before_purge will be removed without replacement in ActiveEncode 0.3")
        set_callback(:purge, :before, *filters, &blk)
      end

      def self.after_purge(*filters, &blk)
        ActiveSupport::Deprecation.warn("after_purge will be removed without replacement in ActiveEncode 0.3")
        set_callback(:purge, :after, *filters, &blk)
      end

      def self.around_purge(*filters, &blk)
        ActiveSupport::Deprecation.warn("around_purge will be removed without replacement in ActiveEncode 0.3")
        set_callback(:purge, :around, *filters, &blk)
      end
    end
  end
end
