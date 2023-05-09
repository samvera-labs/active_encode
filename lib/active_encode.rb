# frozen_string_literal: true
require 'active_encode/version'
require 'active_encode/base'
require 'active_encode/engine'
require 'active_encode/filename_sanitizer'

module ActiveEncode
  extend ActiveEncode::FilenameSanitizer
end
