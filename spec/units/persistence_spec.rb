# frozen_string_literal: true
require 'rails_helper'

describe ActiveEncode::Persistence, db_clean: true do
  before do
    class CustomEncode < ActiveEncode::Base
      include ActiveEncode::Persistence
    end
  end

  after do
    Object.send(:remove_const, :CustomEncode)
  end

  describe 'find' do
    subject { ActiveEncode::EncodeRecord.find_by(global_id: encode.to_global_id.to_s) }
    let(:encode) { CustomEncode.create(nil) }

    it 'persists changes on find' do
      expect { CustomEncode.find(encode.id) }.to change { subject.reload.updated_at }
    end
  end

  describe 'create' do
    subject { ActiveEncode::EncodeRecord.find_by(global_id: encode.to_global_id.to_s) }
    let(:create_options) { { option: 'value' } }
    let(:encode) { CustomEncode.create(nil, create_options) }

    it 'creates a record' do
      expect { encode }.to change { ActiveEncode::EncodeRecord.count }.by(1)
    end

    its(:global_id) { is_expected.to eq encode.to_global_id.to_s }
    its(:state) { is_expected.to eq encode.state.to_s }
    its(:adapter) { is_expected.to eq encode.class.engine_adapter.class.name }
    its(:title) { is_expected.to eq encode.input.url.to_s }
    its(:raw_object) { is_expected.to eq encode.to_json }
    its(:created_at) { is_expected.to be_within(1.second).of encode.created_at }
    its(:updated_at) { is_expected.to be_within(1.second).of encode.updated_at }
    its(:create_options) { is_expected.to eq create_options.to_json }
  end

  describe 'cancel' do
    subject { ActiveEncode::EncodeRecord.find_by(global_id: encode.to_global_id.to_s) }
    let(:encode) { CustomEncode.create(nil) }

    it 'persists changes on cancel' do
      expect { encode.cancel! }.to change { subject.reload.state }.from("running").to("cancelled")
    end
  end

  describe 'reload' do
    subject { ActiveEncode::EncodeRecord.find_by(global_id: encode.to_global_id.to_s) }
    let(:encode) { CustomEncode.create(nil) }

    it 'persists changes on reload' do
      expect { encode.reload }.to change { subject.reload.updated_at }
    end
  end
end
