require 'active_support'

module ActiveEncode
  module TechnicalMetadata
    extend ActiveSupport::Concern

    included do
      attr_accessor :tech_metadata
    end
  end
end
