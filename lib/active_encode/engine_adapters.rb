module ActiveEncode
  # == Active Encode adapters
  #
  # Active Encode has adapters for the following engines:
  #
  #
  #
  module QueueAdapters
    extend ActiveSupport::Autoload

    autoload :ActiveJobAdapter
    autoload :MatterhornAdapter

    ADAPTER = 'Adapter'.freeze
    private_constant :ADAPTER

    class << self
      def lookup(name)
        const_get(name.to_s.camelize << ADAPTER)
      end
    end
  end
end
