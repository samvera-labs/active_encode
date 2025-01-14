# frozen_string_literal: true
require 'active_support'

module ActiveEncode
  module SubtitleTechnicalMetadata
    extend ActiveSupport::Concern

    included do
      attr_accessor :language
      attr_accessor :codec
      attr_accessor :format
    end

    def assign_subtitle_tech_metadata(metadata)
      [:language, :codec, :format].each do |field|
        send("#{field}=", metadata[field]) if metadata.key?(field)
      end
    end
  end
end
