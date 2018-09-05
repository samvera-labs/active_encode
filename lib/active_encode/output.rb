module ActiveEncode
  class Output
    include Status
    include TechnicalMetadata

    attr_accessor :id
    attr_accessor :url
  end
end
