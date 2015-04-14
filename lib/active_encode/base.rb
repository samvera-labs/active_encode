require 'active_encode/core'
require 'active_encode/engine_adapter'
require 'active_encode/status'
require 'active_encode/technical_metadata'
require 'active_encode/callbacks'
#require 'active_encode/logging'

module ActiveEncode #:nodoc:
  class Base
    include Core
    include Status
    include TechnicalMetadata
    include EngineAdapter
    include Callbacks
  end
end
