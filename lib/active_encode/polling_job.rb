class ActiveEncode::PollingJob

  def perform(job)
    job.run_callbacks(:status_update)
    case job.status
    when :error
      job.run_callbacks(:error)
    when :cancelled
      # TODO do we need cancelled
      job.run_callbacks(:cancelled)
    when :complete
      job.run_callbacks(:complete)
    else
      PollingJob.perform_later(self, wait: Polling::POLLING_WAIT_TIME)
    end
  end

end
