# frozen_string_literal: true

RSpec.describe Resque::Plugins::Queue::Status do
  let(:queue_status_key) { 'queue:status:key' }

  after(:each) do
    Job.clear_all_queue_statuses
    FailJob.clear_all_queue_statuses
  end

  class Job
    extend Resque::Plugins::Queue::Status

    def self.queue
      :status_test
    end

    def self.perform(*); end
  end

  class FailJob
    extend Resque::Plugins::Queue::Status

    def self.queue
      :status_test_fail
    end

    def self.perform(*)
      raise 'FAIL'
    end
  end

  it 'has a version number' do
    expect(Resque::Plugins::Queue::Status::VERSION).not_to be nil
  end

  it 'lints as a Resque plugin' do
    Resque::Plugin.lint(Resque::Plugins::Queue::Status)
  end

  it 'status in PROCESS when it begins' do
    Resque.enqueue(Job, queue_status_key: queue_status_key)
    expect(Job.current_queue_status(queue_status_key)[:status])
      .to eq 'PROCESS'
  end

  it 'status in COMPLETE when it finishes' do
    Resque.enqueue(Job, queue_status_key: queue_status_key)
    expect(Job.current_queue_status(queue_status_key)[:status])
      .to eq 'PROCESS'

    klass = Resque.reserve(Job.queue)
    klass.perform
    expect(Job.current_queue_status(queue_status_key)[:status])
      .to eq 'COMPLETE'
  end

  it 'status in FAIL when it throws an exception' do
    Resque.enqueue(FailJob, queue_status_key: queue_status_key)
    expect(FailJob.current_queue_status(queue_status_key)[:status])
      .to eq 'PROCESS'

    klass = Resque.reserve(FailJob.queue)
    expect { klass.perform }.to raise_error 'FAIL'

    expect(FailJob.current_queue_status(queue_status_key)[:status])
      .to eq 'FAIL'
  end

  it 'deletes all keys' do
    Resque.enqueue(Job, queue_status_key: queue_status_key)
    expect(!Job.all_queue_statuses.empty?).to eq true

    Job.clear_all_queue_statuses
    expect(!Job.all_queue_statuses.empty?).to eq false
  end
end
