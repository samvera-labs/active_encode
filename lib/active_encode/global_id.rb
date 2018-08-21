require 'globalid'

module ActiveEncode
  module GlobalID
    extend ActiveSupport::Concern
    include ::GlobalID::Identification

    def to_global_id
      super(app: 'ActiveEncode')
    end
  end
end
