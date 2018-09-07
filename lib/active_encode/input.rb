module ActiveEncode
  class Input
    include Status
    include TechnicalMetadata

    attr_accessor :id
    attr_accessor :url

    def valid?
      id.present? && url.present? &&
      created_at.is_a?(Time) && updated_at.is_a?(Time) &&
      updated_at >= created_at
    end

    # Assign values from a Hash
    def assign_tech_metadata tech_md
      tech_md.each_key do |field|
       self.send("#{field}=", tech_md[field])
      end
    end
  end
end
