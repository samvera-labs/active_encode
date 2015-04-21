require 'rubyhorn'

module ActiveEncode
  module EngineAdapters
    class MatterhornAdapter
      DEFAULT_ARGS = {'flavor' => 'presenter/source'}
      def create(encode)
        workflow_id = encode.options[:preset] || "full"
        workflow = Rubyhorn.client.addMediaPackageWithUrl(DEFAULT_ARGS.merge({'workflow' => workflow_id, 'url' => encode.input, 'filename' => File.basename(encode.input), 'title' => File.basename(encode.input)}))
        #encode.id = convert_id(workflow.ng_xml.remove_namespaces!)
        #encode.state = convert_state(workflow.ng_xml.remove_namespaces!)
        #encode
        encode = build_encode(workflow, encode.class)
        encode
      end

      def find(id, opts = {})
        workflow = begin
          Rubyhorn.client.instance_xml(id)
        rescue Rubyhorn::RestClient::Exceptions::HTTPNotFound
          nil
        end

        workflow ||= begin
          Rubyhorn.client.get_stopped_workflow(id)
        rescue
          nil
        end

        build_encode(workflow, opts[:cast])
      end

      def list(*filters)
        raise NotImplementedError #TODO implement this
      end

      def cancel(encode)
        workflow = Rubyhorn.client.stop(encode.id)
        build_encode(workflow, encode.class)
      end

      def purge(encode)
        workflow = Rubyhorn.client.stop(encode.id) rescue nil
        workflow ||= Rubyhorn.client.get_stopped_workflow(encode.id) rescue nil
        media_package = Rubyhorn.client.get_media_package_from_id(workflow.ng_xml.xpath('//mediapackage/@id').to_s)
        workflow.ng_xml.xpath('//track[@type="presenter/delivery" and tags/tag[text()="streaming"]]/@id').map(&:to_s).each do |track_id|
          Rubyhorn.client.delete_track(media_package, track_id) rescue nil
        end
        workflow.ng_xml.xpath('//track[@type="presenter/delivery" and tags/tag[text()="streaming"] and tags/tag[text()="hls"]]/@id').map(&:to_s).each do |hls_track_id|
          Rubyhorn.client.delete_hls_track(media_package, hls_track_id) rescue nil
        end
        #Rubyhorn.client.delete_instance(encode.id) #Delete is not working so workflow instances can always be retrieved later!
        build_encode(workflow, encode.class)
      end

      private
      def build_encode(workflow_om, cast)
        return nil if workflow_om.nil?
        workflow = if workflow_om.ng_xml.is_a? Nokogiri::XML::Document
          workflow_om.ng_xml.remove_namespaces!.root
        else
          workflow_om.ng_xml
        end
        return nil if workflow.nil?
        encode = cast.new(convert_input(workflow), convert_output(workflow), convert_options(workflow))
        encode.id = convert_id(workflow)
        encode.state = convert_state(workflow)
        encode.current_operations = convert_current_operations(workflow)
        encode.errors = convert_errors(workflow)
        encode.tech_metadata = convert_tech_metadata(workflow)
        encode
      end

      def convert_id(workflow)
        workflow.attribute('id').to_s
      end

      def convert_state(workflow)
        case workflow.attribute('state').to_s
        when "INSTANTIATED", "RUNNING" #Should there be a queued state?
          :running
        when "STOPPED"
          :cancelled
        when "FAILED"
          workflow.xpath('//operation[@state="FAILED"]').empty? ? :cancelled : :failed
        when "SUCCEEDED", "SKIPPED" #Should there be a errored state?
          :completed
        end
      end

      def convert_input(workflow)
        #Need to do anything else since this is a MH url? and this disappears when a workflow is cleaned up
        workflow.xpath('mediapackage/media/track[@type="presenter/source"]/url/text()').to_s
      end

      def convert_tech_metadata(workflow)
        convert_track_metadata(workflow.xpath('//track[@type="presenter/source"]').first)
      end

      def convert_output(workflow)
        output = {}
        workflow.xpath('//track[@type="presenter/delivery"]').each do |track|
          label = track.xpath('tags/tag[starts-with(text(),"quality")]/text()').to_s
          url = track.at("url/text()").to_s
          output[label] = convert_track_metadata(track).merge({url: url})
        end
        output
      end

      def convert_current_operations(workflow)
        workflow.xpath('//operation[@state!="INSTANTIATED"]/@description').last.to_s
      end

      def convert_errors(workflow)
        workflow.xpath('//errors/error/text()').map(&:to_s)
      end

      def convert_options(workflow)
        options = {}
        options[:preset] = workflow.xpath('template/text()').to_s
        options
      end

      def convert_track_metadata(track)
        return {} if track.nil?
        metadata = {}
        metadata[:mime_type] = track.at("mimetype/text()").to_s if track.at('mimetype')
        metadata[:checksum] = track.at("checksum/text()").to_s if track.at('checksum')
        metadata[:duration] = track.at("duration/text()").to_s if track.at('duration')
        if track.at('audio')
          metadata[:audio_codec] = track.at("audio/encoder/@type").to_s 
          metadata[:audio_channels] = track.at("audio/channels/text()").to_s
          metadata[:audio_bitrate] = track.at("audio/bitrate/text()").to_s
        end
        if track.at('video')
          metadata[:video_codec] = track.at("video/encoder/@type").to_s
          metadata[:video_bitrate] = track.at("video/bitrate/text()").to_s
          metadata[:video_framerate] = track.at("video/framerate/text()").to_s
          metadata[:width] = track.at("video/resolution/text()").to_s.split('x')[0]
          metadata[:height] = track.at("video/resolution/text()").to_s.split('x')[1]
        end
        metadata
      end
    end
  end
end
