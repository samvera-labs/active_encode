require 'spec_helper'

describe 'ActiveEncode::Status' do

  subject { ActiveEncode::Base.new(nil) }

  context 'new object' do
    subject {ActiveEncode::Base.new(nil)}
    it { is_expected.not_to be_created }
    it { is_expected.not_to be_running }
    it { is_expected.not_to be_cancelled }
    it { is_expected.not_to be_completed }
    it { is_expected.not_to be_failed }
  end

  context 'running job' do
    before do
      subject.id = 1
      subject.state = :running
    end
    it { is_expected.to be_created }
    it { is_expected.to be_running }
    it { is_expected.not_to be_cancelled }
    it { is_expected.not_to be_completed }
    it { is_expected.not_to be_failed }
  end

  context 'cancelled job' do
    before do
      subject.id = 1
      subject.state = :cancelled
    end
    it { is_expected.to be_created }
    it { is_expected.not_to be_running }
    it { is_expected.to be_cancelled }
    it { is_expected.not_to be_completed }
    it { is_expected.not_to be_failed }
  end

  context 'completed job' do
    before do
      subject.id = 1
      subject.state = :completed
    end
    it { is_expected.to be_created }
    it { is_expected.not_to be_running }
    it { is_expected.not_to be_cancelled }
    it { is_expected.to be_completed }
    it { is_expected.not_to be_failed }
  end

  context 'failed job' do
    before do
      subject.id = 1
      subject.state = :failed
    end
    it { is_expected.to be_created }
    it { is_expected.not_to be_running }
    it { is_expected.not_to be_cancelled }
    it { is_expected.not_to be_completed }
    it { is_expected.to be_failed }
  end

end
