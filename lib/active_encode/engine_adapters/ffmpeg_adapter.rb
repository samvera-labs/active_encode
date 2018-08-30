module ActiveEncode
  module EngineAdapters
    class FfmpegAdapter
      def create(encode)
        new_encode = encode.class.new(encode.input, encode.options)
        new_encode.id = SecureRandom.uuid
        # TODO mkdir(File.join(working_dir,new_encode.id))
        new_encode
      end

      def find(id, opts={})
      end

      def cancel(encode)
      end
    end
  end
end
