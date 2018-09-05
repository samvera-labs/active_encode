require 'spec_helper'

describe ActiveEncode::Core do
  before do
    class CustomEncode < ActiveEncode::Base
    end
  end
   after do
    Object.send(:remove_const, :CustomEncode)
  end

  let(:encode_class) { ActiveEncode::Base }

  describe 'attributes' do
    subject { encode_class.new(nil) }

    it { is_expected.to respond_to(:id, :input, :output, :options, :percent_complete, :current_operations) }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to respond_to(:id, :input, :output, :options, :percent_complete, :current_operations) }
    end
  end

  describe 'find' do
    let(:id) { encode_class.create(nil).id }
    subject { encode_class.find(id) }

    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.to eq id }

    context 'with no id' do
      let(:id) { nil }

      it 'raises an error' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.to eq id }

      context 'casting' do
        let(:id) { ActiveEncode::Base.create(nil).id }

        it { is_expected.to be_a encode_class }
        its(:id) { is_expected.to eq id }
      end
    end
  end

  describe 'create' do
    subject { encode_class.create(nil) }

    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.not_to be nil }
    its(:state) { is_expected.not_to be nil }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.not_to be nil }
      its(:state) { is_expected.not_to be nil }
    end
  end

  describe '#create!' do
    let(:encode) { encode_class.new(nil) }
    subject { encode.create! }

    it { is_expected.to equal encode }
    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.not_to be nil }
    its(:state) { is_expected.not_to be nil }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to equal encode }
      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.not_to be nil }
      its(:state) { is_expected.not_to be nil }
    end
  end

  describe '#cancel!' do
    let(:encode) { encode_class.create(nil) }
    subject { encode.cancel! }

    it { is_expected.to equal encode }
    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.not_to be nil }
    it { is_expected.to be_cancelled }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to equal encode }
      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.not_to be nil }
      it { is_expected.to be_cancelled }
    end
  end

  describe '#reload' do
    let(:encode) { encode_class.create(nil) }
    subject { encode.reload }

    it { is_expected.to equal encode }
    it { is_expected.to be_a encode_class }
    its(:id) { is_expected.not_to be nil }
    its(:state) { is_expected.not_to be nil }

    context 'with an ActiveEncode::Base subclass' do
      let(:encode_class) { CustomEncode }

      it { is_expected.to equal encode }
      it { is_expected.to be_a encode_class }
      its(:id) { is_expected.not_to be nil }
      its(:state) { is_expected.not_to be nil }
    end
  end
end
