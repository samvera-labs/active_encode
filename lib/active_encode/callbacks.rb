require 'active_support/callbacks'

module ActiveEncode
  # = Active Encode Callbacks
  #
  # Active Encode provides hooks during the life cycle of an encode. Callbacks allow you
  # to trigger logic during the life cycle of an encode. Available callbacks are:
  #
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
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks

    included do
      define_callbacks :create
      define_callbacks :cancel
      define_callbacks :purge
    end

    # These methods will be included into any Active Encode object, adding
    # callbacks for +create+, +cancel+, and +purge+ methods.
    module ClassMethods
      def before_create(*filters, &blk)
        set_callback(:create, :before, *filters, &blk)
      end
      
      def after_create(*filters, &blk)
        set_callback(:create, :after, *filters, &blk)
      end

      def around_create(*filters, &blk)
        set_callback(:create, :around, *filters, &blk)
      end

      def before_cancel(*filters, &blk)
        set_callback(:cancel, :before, *filters, &blk)
      end
      
      def after_cancel(*filters, &blk)
        set_callback(:cancel, :after, *filters, &blk)
      end

      def around_cancel(*filters, &blk)
        set_callback(:cancel, :around, *filters, &blk)
      end

      def before_purge(*filters, &blk)
        set_callback(:purge, :before, *filters, &blk)
      end
      
      def after_purge(*filters, &blk)
        set_callback(:purge, :after, *filters, &blk)
      end

      def around_purge(*filters, &blk)
        set_callback(:purge, :around, *filters, &blk)
      end
    end
  end
end
