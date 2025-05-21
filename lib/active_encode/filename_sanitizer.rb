# frozen_string_literal: true
module ActiveEncode
  module FilenameSanitizer
    # ffmpeg has trouble with double quotes in file names. Escape them to get ffmpeg to find the file.
    def sanitize_input(input_url)
      input_url.gsub(/["]/, '\\\\\0')
    end

    def sanitize_base(input_url)
      filepath = input_url.is_a?(URI::HTTP) ? input_url.path : input_url
      # Replace special characters with underscores and remove excess periods.
      # This removes the extension before processing so it is safe to delete all detected periods.
      # This explicitly handles percent encoded spaces.
      File.basename(filepath, File.extname(filepath)).gsub(/%20/, "_").gsub(/[^0-9A-Za-z.\-\/]/, '_').delete('.')
    end

    def sanitize_filename(input_url)
      filepath = input_url.is_a?(URI::HTTP) ? input_url.path : input_url
      # Replace special characters with underscores and remove excess periods.
      File.basename(filepath).gsub(/[^0-9A-Za-z.\-\/]/, '_').gsub(/\.(?=.*\.)/, '')
    end

    def sanitize_uri(input_url)
      case input_url
      when /^file\:\/\/\//
        input_url.to_s.gsub(/file:\/\//, '')
      when /^s3\:\/\//
        input_url.to_s.gsub(/#{Addressable::URI.parse(input_url).site}/, '')
      when /^https?:\/\//
        input_url
      end
    end
  end
end
