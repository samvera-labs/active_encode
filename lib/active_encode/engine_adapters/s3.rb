require 'addressable/uri'
require 'file_locator'

module ActiveEncode
  module EngineAdapters
    module S3
      extend ActiveSupport::Concern

      protected

      def s3client
        Aws::S3::Client.new
      end

      def copy_to_input_bucket(input_url, bucket)
        case Addressable::URI.parse(input_url).scheme
        when nil, 'file'
          upload_to_s3 input_url, bucket
        when 's3'
          check_s3_bucket input_url, bucket
        end
      end

      def check_s3_bucket(input_url, source_bucket)
        # logger.info("Checking `#{input_url}'")
        s3_object = FileLocator::S3File.new(input_url).object
        if s3_object.bucket_name == source_bucket
          # logger.info("Already in bucket `#{source_bucket}'")
          s3_object.key
        else
          s3_key = File.join(SecureRandom.uuid, s3_object.key)
          # logger.info("Copying to `#{source_bucket}/#{input_url}'")
          target = Aws::S3::Object.new(bucket_name: source_bucket, key: input_url)
          target.copy_from(s3_object, multipart_copy: s3_object.size > 15_728_640) # 15.megabytes
          s3_key
        end
      end

      def upload_to_s3(input_url, source_bucket)
        # original_input = input_url
        bucket = Aws::S3::Resource.new(client: s3client).bucket(source_bucket)
        filename = FileLocator.new(input_url).location
        s3_key = File.join(SecureRandom.uuid, File.basename(filename))
        # logger.info("Copying `#{original_input}' to `#{source_bucket}/#{input_url}'")
        obj = bucket.object(s3_key)
        obj.upload_file filename

        s3_key
      end
    end
  end
end

