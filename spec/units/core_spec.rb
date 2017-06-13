require 'spec_helper'

describe ActiveEncode::Core do
  describe 'find' do
    it "raises NotFound when no id is supplied" do
      expect { ActiveEncode::Base.find(nil) }.to raise_error(ActiveEncode::NotFound)
    end
  end
end
