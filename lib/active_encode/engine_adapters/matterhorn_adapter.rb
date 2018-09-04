require 'rubyhorn'

module ActiveEncode
  module EngineAdapters
    class MatterhornAdapter
      DEFAULT_ARGS = { 'flavor' => 'presenter/source' }.freeze

      def create(encode)
        workflow_id = encode.options[:preset] || "full"
        # workflow_om = if encode.input.is_a? Hash
        #                 create_multiple_files(encode.input, workflow_id)
        #               else
                        workflow_om = Rubyhorn.client.addMediaPackageWithUrl(DEFAULT_ARGS.merge('workflow' => workflow_id, 'url' => encode.input.url, 'filename' => File.basename(encode.input.url), 'title' => File.basename(encode.input.url)))
                      # end
        build_encode(get_workflow(workflow_om))
      end

      def find(id, opts = {})
        build_encode(fetch_workflow(id))
      end

      def list(*_filters)
        raise NotImplementedError # TODO: implement this
      end

      def cancel(encode)
        workflow_om = Rubyhorn.client.stop(encode.id)
        build_encode(get_workflow(workflow_om))
      end

      def purge(encode)
        workflow_om = begin
                        Rubyhorn.client.stop(encode.id)
                      rescue
                        nil
                      end
        workflow_om ||= begin
                          Rubyhorn.client.get_stopped_workflow(encode.id)
                        rescue
                          nil
                        end
        purged_workflow = purge_outputs(get_workflow(workflow_om))
        # Rubyhorn.client.delete_instance(encode.id) #Delete is not working so workflow instances can always be retrieved later!
        build_encode(purged_workflow)
      end

      def remove_output(encode, output_id)
        workflow = fetch_workflow(encode.id)
        output = encode.output.find { |o| o[:id] == output_id }
        return if output.nil?
        purge_output(workflow, output_id)
        output
      end

      private

        def fetch_workflow(id)
          workflow_om = begin
            Rubyhorn.client.instance_xml(id)
          rescue Rubyhorn::RestClient::Exceptions::HTTPNotFound
            nil
          end

          workflow_om ||= begin
            Rubyhorn.client.get_stopped_workflow(id)
          rescue
            nil
          end

          get_workflow(workflow_om)
        end

        def get_workflow(workflow_om)
          return nil if workflow_om.nil?
          if workflow_om.ng_xml.is_a? Nokogiri::XML::Document
            workflow_om.ng_xml.remove_namespaces!.root
          else
            workflow_om.ng_xml
          end
        end

        def build_encode(workflow)
          return nil if workflow.nil?
          encode = ActiveEncode::Base.new(convert_input(workflow), convert_options(workflow))
          encode.id = convert_id(workflow)
          encode.state = convert_state(workflow)
          encode.current_operations = convert_current_operations(workflow)
          encode.percent_complete = calculate_percent_complete(workflow)
          encode.created_at = convert_created_at(workflow)
          encode.updated_at = convert_updated_at(workflow)
          encode.finished_at = convert_finished_at(workflow) unless encode.running?
          encode.output = convert_output(workflow, encode.options)
          encode.errors = convert_errors(workflow)
          encode.tech_metadata = convert_tech_metadata(workflow)
          encode
        end

        def convert_id(workflow)
          workflow.attribute('id').to_s
        end

        def convert_state(workflow)
          case workflow.attribute('state').to_s
          when "INSTANTIATED", "RUNNING" # Should there be a queued state?
            :running
          when "STOPPED"
            :cancelled
          when "FAILED"
            workflow.xpath('//operation[@state="FAILED"]').empty? ? :cancelled : :failed
          when "SUCCEEDED", "SKIPPED" # Should there be a errored state?
            :completed
          end
        end

        def convert_input(workflow)
          # Need to do anything else since this is a MH url? and this disappears when a workflow is cleaned up
          workflow.xpath('mediapackage/media/track[@type="presenter/source"]/url/text()').to_s
        end

        def convert_tech_metadata(workflow)
          convert_track_metadata(workflow.xpath('//track[@type="presenter/source"]').first)
        end

        def convert_output(workflow, options)
          output = []
          workflow.xpath('//track[@type="presenter/delivery" and tags/tag[text()="streaming"]]').each do |track|
            label = track.xpath('tags/tag[starts-with(text(),"quality")]/text()').to_s
            url = track.at("url/text()").to_s
            if url.start_with? "rtmp"
              url = File.join(options[:stream_base], MatterhornRtmpUrl.parse(url).to_path) if options[:stream_base]
            end
            track_id = track.at("@id").to_s
            output << convert_track_metadata(track).merge(id: track_id, url: url, label: label)
          end
          output
        end

        def convert_current_operations(workflow)
          current_op = workflow.xpath('//operation[@state!="INSTANTIATED"]/@description').last.to_s
          current_op.present? ? [current_op] : []
        end

        def convert_errors(workflow)
          workflow.xpath('//errors/error/text()').map(&:to_s)
        end

        def convert_created_at(workflow)
          created_at = workflow.xpath('mediapackage/@start').last.to_s
          created_at.present? ? Time.parse(created_at) : nil
        end

        def convert_updated_at(workflow)
          updated_at = workflow.xpath('//operation[@state!="INSTANTIATED"]/completed/text()').last.to_s
          updated_at.present? ? Time.strptime(updated_at, "%Q") : nil
        end

        def convert_finished_at(workflow)
          finished_at = workflow.xpath('//operation[@state!="INSTANTIATED"]/completed/text()').last.to_s
          finished_at.present? ? Time.strptime(finished_at, "%Q") : nil
        end

        def convert_options(workflow)
          options = {}
          options[:preset] = workflow.xpath('template/text()').to_s
          options[:stream_base] = workflow.xpath('//properties/property[@key="avalon.stream_base"]/text()').to_s if workflow.xpath('//properties/property[@key="avalon.stream_base"]/text()').present? # this is avalon-felix specific
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

        def get_media_package(workflow)
          mp = workflow.xpath('//mediapackage')
          first_node = mp.first
          first_node['xmlns'] = 'http://mediapackage.opencastproject.org'
          mp
        end

        def purge_outputs(workflow)
          # Delete hls tracks first since the next, more general xpath matches them as well
          workflow.xpath('//track[@type="presenter/delivery" and tags/tag[text()="streaming"] and tags/tag[text()="hls"]]/@id').map(&:to_s).each do |hls_track_id|
            begin
              purge_output(workflow, hls_track_id)
            rescue
              nil
            end
          end
          workflow.xpath('//track[@type="presenter/delivery" and tags/tag[text()="streaming"]]/@id').map(&:to_s).each do |track_id|
            begin
              purge_output(workflow, track_id)
            rescue
              nil
            end
          end

          workflow
        end

        def purge_output(workflow, track_id)
          media_package = get_media_package(workflow)
          hls = workflow.xpath("//track[@id='#{track_id}']/tags/tag[text()='hls']").present?
          job_url = if hls
                      Rubyhorn.client.delete_hls_track(media_package, track_id)
                    else
                      Rubyhorn.client.delete_track(media_package, track_id)
                    end
          sleep(0.1)
          job_status = Nokogiri::XML(Rubyhorn.client.get(URI(job_url).path)).root.attribute("status").value
          # FIXME: have this return a boolean based upon result of operation
          case job_status
          when "FINISHED"
            workflow.at_xpath("//track[@id=\"#{track_id}\"]").remove
          when "FAILED"
            workflow.at_xpath('//errors').add_child("<error>Output not purged: #{mp.at_xpath("//*[@id=\"#{track_id}\"]/tags/tag[starts-with(text(),\"quality\")]/text()")}</error>")
          end
        end

        def calculate_percent_complete(workflow)
          totals = {
            transcode: 70,
            distribution: 20,
            other: 10
          }

          completed_transcode_operations = workflow.xpath('//operation[@id="compose" and (@state="SUCCEEDED" or @state="SKIPPED")]').size
          total_transcode_operations = workflow.xpath('//operation[@id="compose"]').size
          total_transcode_operations = 1 if total_transcode_operations.zero?
          completed_distribution_operations = workflow.xpath('//operation[starts-with(@id,"distribute") and (@state="SUCCEEDED" or @state="SKIPPED")]').size
          total_distribution_operations = workflow.xpath('//operation[starts-with(@id,"distribute")]').size
          total_distribution_operations = 1 if total_distribution_operations.zero?
          completed_other_operations = workflow.xpath('//operation[@id!="compose" and not(starts-with(@id,"distribute")) and (@state="SUCCEEDED" or @state="SKIPPED")]').size
          total_other_operations = workflow.xpath('//operation[@id!="compose" and not(starts-with(@id,"distribute"))]').size
          total_other_operations = 1 if total_other_operations.zero?

          ((totals[:transcode].to_f / total_transcode_operations) * completed_transcode_operations) +
            ((totals[:distribution].to_f / total_distribution_operations) * completed_distribution_operations) +
            ((totals[:other].to_f / total_other_operations) * completed_other_operations)
        end

        def create_multiple_files(input, workflow_id)
          # Create empty media package xml document
          mp = Rubyhorn.client.createMediaPackage

          # Next line associates workflow title to avalon via masterfile pid
          title = File.basename(input.values.first)
          dc = Nokogiri::XML('<dublincore xmlns="http://www.opencastproject.org/xsd/1.0/dublincore/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dcterms:title>' + title + '</dcterms:title></dublincore>')
          mp = Rubyhorn.client.addDCCatalog('mediaPackage' => mp.to_xml, 'dublinCore' => dc.to_xml, 'flavor' => 'dublincore/episode')

          # Add quality levels - repeated for each supplied file url
          input.each_pair do |quality, url|
            mp = Rubyhorn.client.addTrack('mediaPackage' => mp.to_xml, 'url' => url, 'flavor' => DEFAULT_ARGS['flavor'])
            # Rewrite track to include quality tag
            # Get the empty tags element under the newly added track
            tags = mp.xpath('//xmlns:track/xmlns:tags[not(node())]', 'xmlns' => 'http://mediapackage.opencastproject.org').first
            quality_tag = Nokogiri::XML::Node.new 'tag', mp
            quality_tag.content = quality
            tags.add_child quality_tag
          end
          # Finally ingest the media package
          begin
                  Rubyhorn.client.start("definitionId" => workflow_id, "mediapackage" => mp.to_xml)
                rescue Rubyhorn::RestClient::Exceptions::HTTPBadRequest
                  # make this two calls...one to get the workflow definition xml and then the second to submit it along with the mediapackage to start...due to unsolved issue with some MH installs
                  begin
                          workflow_definition_xml = Rubyhorn.client.definition_xml(workflow_id)
                          Rubyhorn.client.start("definition" => workflow_definition_xml, "mediapackage" => mp.to_xml)
                        rescue Rubyhorn::RestClient::Exceptions::HTTPNotFound
                          raise StandardError, "Unable to start workflow"
                        end
                end
        end
    end

    class MatterhornRtmpUrl
      class_attribute :members
      self.members = %i[application prefix media_id stream_id filename extension]
      attr_accessor(*members)
      REGEX = %r{^
  /(?<application>.+)        # application (avalon)
  /(?:(?<prefix>.+):)?       # prefix      (mp4:)
  (?<media_id>[^\/]+)        # media_id    (98285a5b-603a-4a14-acc0-20e37a3514bb)
  /(?<stream_id>[^\/]+)      # stream_id   (b3d5663d-53f1-4f7d-b7be-b52fd5ca50a3)
  /(?<filename>.+?)          # filename    (MVI_0057)
  (?:\.(?<extension>.+))?$   # extension   (mp4)
      }x

      # @param [MatchData] match_data
      def initialize(match_data)
        self.class.members.each do |key|
          send("#{key}=", match_data[key])
        end
      end

      def self.parse(url_string)
        # Example input: /avalon/mp4:98285a5b-603a-4a14-acc0-20e37a3514bb/b3d5663d-53f1-4f7d-b7be-b52fd5ca50a3/MVI_0057.mp4

        uri = URI.parse(url_string)
        match_data = REGEX.match(uri.path)
        MatterhornRtmpUrl.new match_data
      end

      alias _binding binding
      def binding
        _binding
      end

      def to_path
        File.join(media_id, stream_id, "#{filename}.#{extension || prefix}")
      end
    end
  end
end
