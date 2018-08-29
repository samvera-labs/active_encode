module ActiveEncode
  class PollingJob < ActiveJob::Base
    # TODO do we need the following?
    # include ActiveEncode::Core  #I'm not sure if the error callback is really makes sense here!
    # queue_as :active_encode_update
    # throttle threshold: Settings.encode_throttling.update_jobs_throttle_threshold, period: Settings.encode_throttling.update_jobs_spacing, drop: false

    def perform(encode)
      # TODO need to check encode is nil?
      return unless encode

      encode.run_callbacks(:status_update) { encode }
      case encode.state
      when :error
        encode.run_callbacks(:error) { encode }
      when :cancelled
        encode.run_callbacks(:cancelled) { encode }
      when :complete
        encode.run_callbacks(:complete) { encode }
      when :running
        ActiveEncode::PollingJob.set(wait: ActiveEncode::Polling::POLLING_WAIT_TIME).perform_later(encode)
      else # other states are illegal and ignored
        raise StandardError, "Illegal state #{encode.state} in encode #{encode.id}!"
      end
    end
  end
end
