# frozen_string_literal: true
module ActiveEncode
  module FilenameSanitizer
    # ffmpeg has trouble with double quotes in file names. Escape them to get ffmpeg to find the file.
    def sanitize_input(input_url)
      input_url.gsub(/["]/, '\\\\\0')
    end

    def sanitize_base(input_url)
      # Replace special characters with underscores and remove excess periods.
      if input_url.is_a? URI::HTTP
        # This removes the extension before processing so it is safe to delete all detected periods.
        File.basename(input_url.path, File.extname(input_url.path)).gsub(/[^0-9A-Za-z.\-\/]/, '_').delete('.')
      else
        File.basename(input_url, File.extname(input_url)).gsub(/[^0-9A-Za-z.\-\/]/, '_').delete('.')
      end
    end

    def sanitize_filename(input_url)
      # Replace special characters with underscores and remove excess periods.
      if input_url.is_a? URI::HTTP
        File.basename(input_url.path).gsub(/[^0-9A-Za-z.\-\/]/, '_').gsub(/\.(?=.*\.)/, '')
      else
        File.basename(input_url).gsub(/[^0-9A-Za-z.\-\/]/, '_').gsub(/\.(?=.*\.)/, '')
      end
    end
  end
end
