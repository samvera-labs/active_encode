require 'rubyhorn'

module ActiveEncode
  module EngineAdapters
    class MatterhornAdapter
      DEFAULT_ARGS = {'flavor' => 'presenter/source'}
      def create(encode)
        workflow = Rubyhorn.client.addMediaPackageWithUrl(DEFAULT_ARGS.merge({'workflow' => encode.options[:preset], 'url' => encode.input, 'filename' => File.basename(encode.input), 'title' => File.basename(encode.input)}))
        encode.id = convert_id(workflow.ng_xml.remove_namespaces!)
        encode.state = convert_state(workflow.ng_xml.remove_namespaces!)
        encode
      end

      def find(id, opts = {})
        workflow = begin
          Rubyhorn.client.instance_xml(id)
        rescue Rubyhorn::RestClient::Exceptions::HTTPNotFound
          nil
        end

        build_encode(workflow, opts[:cast])
      end

      def list(*filters)
        raise NotImplementedError #TODO implement this
      end

      def cancel(encode)
        #TODO implement suspend in Rubyhorn
        #workflow = Rubyhorn.client.suspend(encode.id)
        #build_encode(workflow)
        encode.state = :cancelled
        encode
      end

      def purge(encode)
        raise NotImplementedError #TODO implement this
      end

      private
      def build_encode(workflow, cast)
        return nil if workflow.nil?
        workflow_doc = workflow.ng_xml.remove_namespaces!
        encode = cast.new(convert_input(workflow_doc), convert_output(workflow_doc), convert_options(workflow_doc))
        encode.id = convert_id(workflow_doc)
        encode.state = convert_state(workflow_doc)
        encode.current_operations = convert_current_operations(workflow_doc)
        encode.errors = convert_errors(workflow_doc)
        encode
      end

      def convert_id(workflow_doc)
        workflow_doc.root.attribute('id').to_s
      end

      def convert_state(workflow_doc)
        case workflow_doc.root.attribute('state').to_s
        when "INSTANTIATED", "RUNNING" #Should there be a queued state?
          :running
        when "STOPPED"
          :cancelled
        when "FAILED", "SUCCEEDED", "SKIPPED" #Should there be a errored state?
          :completed
        end
      end

      def convert_input(workflow_doc)
        #Need to do anything else since this is a MH url?
        workflow_doc.xpath('workflow/mediapackage/media/track[@type="presenter/source"]/url/text()').to_s
      end

      def convert_tech_metadata(workflow_doc)
        #TODO
      end

      def convert_output(workflow_doc)
        #TODO
      end

      def convert_current_operations(workflow_doc)
        #TODO
      end

      def convert_errors(workflow_doc)
        #TODO
      end

      def convert_options(workflow_doc)
        options = {}
        options[:preset] = workflow_doc.xpath('workflow/template/text()').to_s
        options
      end

      def convert_track_metadata(track)
        #TODO
      end
    end
  end
end
