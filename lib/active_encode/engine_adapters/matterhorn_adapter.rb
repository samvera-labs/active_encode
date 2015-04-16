require 'rubyhorn'

module ActiveEncode
  module EngineAdapters
    class MatterhornAdapter
      DEFAULT_ARGS = {'flavor' => 'presenter/source'}
      def create(encode)
        workflow = Rubyhorn.client.addMediaPackageWithUrl(DEFAULT_ARGS.merge({'workflow' => encode.options[:preset], 'url' => encode.input, 'filename' => File.basename(encode.input), 'title' => File.basename(encode.input)}))
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
        raise NotImplementedError #TODO implement this
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
        #TODO
      end

      def convert_output(workflow)
        #TODO
      end

      def convert_current_operations(workflow)
        workflow.xpath('//operation[@state!="INSTANTIATED"]/@description').last.to_s
      end

      def convert_errors(workflow)
        #TODO
      end

      def convert_options(workflow)
        options = {}
        options[:preset] = workflow.xpath('template/text()').to_s
        options
      end

      def convert_track_metadata(track)
        #TODO
      end
    end
  end
end
