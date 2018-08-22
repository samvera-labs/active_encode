require 'spec_helper'

describe ActiveEncode::PollingJob do
  describe '#perform' do
    let(:encode_class) { ActiveEncode::Base }
    let(:job) { encode_class.create(nil) }

    context "with error" do
      before do
        allow_any_instance_of(ActiveEncode::Base).to receive(:create!).and_raise(StandardError)
      end
      let(:master_file) { FactoryGirl.create(:master_file) }
      it "sets the status of the master file to FAILED" do
        job.perform(master_file.id, nil, {})
        master_file.reload
        expect(master_file.status_code).to eq('FAILED')
      end
    end

    context "with cancelled job" do
      before do
        allow(encode_job).to receive(:id).and_return(nil)
        allow_any_instance_of(ActiveEncode::Base).to receive(:create!).and_return(encode_job)
      end
      let(:encode_job) { ActiveEncode::Base.new(nil) }
      let(:master_file) { FactoryGirl.create(:master_file) }
      it "sets the status of the master file to FAILED" do
        job.perform(master_file.id, nil, {})
        master_file.reload
        expect(master_file.status_code).to eq('FAILED')
      end
    end

    it "ingest PollingJob into the queue" do
      expect { ActiveEncode::Base.find(nil) }.to raise_error(ArgumentError)
    end

  end
end
