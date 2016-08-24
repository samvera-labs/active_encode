module ActiveEncode
  # == Active Encode adapters
  #
  # Active Encode has adapters for the following engines:
  #
  #
  #
  module EngineAdapters
    extend ActiveSupport::Autoload

    autoload :ActiveJobAdapter
    autoload :MatterhornAdapter
    autoload :InlineAdapter
    autoload :ZencoderAdapter
    autoload :ShingoncoderAdapter
    autoload :ElasticTranscoderAdapter
    autoload :TestAdapter

    ADAPTER = 'Adapter'.freeze
    private_constant :ADAPTER

    class << self
      def lookup(name)
        const_get(name.to_s.camelize << ADAPTER)
      end
    end
  end
end
