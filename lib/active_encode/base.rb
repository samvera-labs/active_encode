require 'active_encode/core'
require 'active_encode/engine_adapter'
require 'active_encode/status'
require 'active_encode/technical_metadata'
require 'active_encode/callbacks'
require 'active_encode/global_id'
require 'active_encode/persistence'
require 'active_encode/polling'
require 'active_encode/polling_job'

module ActiveEncode #:nodoc:
  class Base
    include Core
    include Status
    include TechnicalMetadata
    include EngineAdapter
    include Callbacks
    include GlobalID
  end

  class NotFound < RuntimeError; end
end
