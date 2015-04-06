module Hydra
  module Transcoder
    class Base
      
      class << self
        def create(input, output, opts={})
        end
        
        def find(job_id)
        end
        
        def find_by_status(*states)
        end
      end
      
      attr_reader :job_id, :state, :current_operations, :errors, :original_filename, :tech_metadata
      
      def cancel!
      end
      
      def canceled?
      end
      
      def complete?
      end
      
      def purge!
      end
      
      def running?
      end
      
      def update!
      end
    end
  end
end
