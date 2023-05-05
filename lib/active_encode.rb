# frozen_string_literal: true
require 'active_encode/version'
require 'active_encode/base'
require 'active_encode/engine'
require 'active_encode/filename_sanitizer'
require 'active_encode/file_handler'

module ActiveEncode
  extend ActiveEncode::FilenameSanitizer
  extend ActiveEncode::FileHandler
end
