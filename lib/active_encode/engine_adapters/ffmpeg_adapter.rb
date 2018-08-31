require 'fileutils'

module ActiveEncode
  module EngineAdapters
    class FfmpegAdapter
      def create(encode)
        new_encode = encode.class.new(encode.input, encode.options)
        new_encode.id = SecureRandom.uuid
        new_encode.state = :running
        new_encode.current_operations = []
        new_encode.percent_complete = 10
        new_encode.errors = []
        new_encode.created_at = Time.new
        new_encode.tech_metadata = []
        # working_dir = "encodes/" # Should read from config
        # FileUtils.mkdir_p File.join(working_dir, new_encode.id)
        new_encode
      end

      # Return encode object from file system
      def find(id, opts={})
        encode_class = opts[:cast]
        encode = encode_class.new(nil, opts)
        encode.id = id
        encode.state = :running
        encode.current_operations = ["transcoding"]
        encode.percent_complete = 50
        encode.errors = []
        # Read directory timestamps?
        encode.created_at = Time.new
        encode.updated_at = Time.new + 1
        encode.tech_metadata = []
        encode
      end

      # Cancel ongoing encode using pid file
      def cancel(encode)

      end
    end
  end
end
