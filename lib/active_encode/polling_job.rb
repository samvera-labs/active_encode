require 'active_support'
require 'active_encode/callbacks'

class ActiveEncode::PollingJob < ActiveJob::Base
  # TODO do we need the following?
  # include ActiveEncode::Core  #I'm not sure if the error callback is really makes sense here!
  # queue_as :active_encode_update
  # throttle threshold: Settings.encode_throttling.update_jobs_throttle_threshold, period: Settings.encode_throttling.update_jobs_spacing, drop: false

  def perform(job)
    # TODO need to check job is nil?
    return unless job
    run_callbacks(:status_update) { job }
    case job.state
    when :error
      run_callbacks(:error) { job }
    when :cancelled
      run_callbacks(:cancelled) { job }
    when :complete
      run_callbacks(:complete) { job }
    when :running
      PollingJob.perform_later(self, wait: Polling::POLLING_WAIT_TIME)
    else # other states are illegal and ignored
      # TODO throw error?
      raise(StandardError, "Illegal state #{job.state} in job #{job.id}!")
    end
  end
end
