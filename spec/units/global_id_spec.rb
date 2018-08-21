require 'spec_helper'

describe ActiveEncode::GlobalID do
  before do
    class CustomEncode < ActiveEncode::Base
    end
  end

  after do
    Object.send(:remove_const, :CustomEncode)
  end

  describe '#to_global_id' do
    let(:encode_class) { ActiveEncode::Base }
    let(:encode) { encode_class.create(nil) }
    subject { encode.to_global_id }

    it { is_expected.to be_a GlobalID }
    its(:model_class) { is_expected.to eq encode_class }
    its(:model_id) { is_expected.to eq encode.id }
    its(:app) { is_expected.to eq 'ActiveEncode' }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to be_a GlobalID }
      its(:model_class) { is_expected.to eq encode_class }
      its(:model_id) { is_expected.to eq encode.id }
      its(:app) { is_expected.to eq 'ActiveEncode' }
    end
  end

  describe 'GlobalID::Locator#locate' do
    let(:encode_class) { ActiveEncode::Base }
    let(:encode) { encode_class.create(nil) }
    let(:global_id) { encode.to_global_id }
    subject { GlobalID::Locator.locate(global_id) }

    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.to eq encode.id }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }
      
      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.to eq encode.id }
    end
  end
end
