class ActiveEncode::PollingJob
  def perform(job)
    run_callbacks(:status_update) { job }
    case job.status
    when :error
      run_callbacks(:error) { job }
    when :cancelled
      run_callbacks(:cancelled) { job }
    when :complete
      run_callbacks(:complete) { job }
    else
      PollingJob.perform_later(self, wait: Polling::POLLING_WAIT_TIME)
    end
  end
end
