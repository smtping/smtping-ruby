# frozen_string_literal: true

module Smtping
  # Bulk verification: submit a list, poll the job, fetch the results.
  class Bulk
    def initialize(client)
      @client = client
    end

    # Submit up to 100,000 addresses. Duplicates and malformed addresses are removed first.
    def create(emails)
      list = Smtping.normalize(emails, valid_only: true)
      raise ValidationError, "No valid email address in the list" if list.empty?
      raise ValidationError, "A bulk job accepts up to #{BULK_MAX} addresses" if list.size > BULK_MAX

      job = @client.request(:post, "/verify/bulk", { emails: list }) || {}
      job["totalEmails"] ||= list.size
      job
    end

    def get(job_id)
      job = @client.request(:get, "/verify/bulk/#{escape(job_id)}") || {}
      job["jobId"] ||= job_id
      job
    end

    def results(job_id)
      data = @client.request(:get, "/verify/bulk/#{escape(job_id)}/result")
      data = data["results"] if data.is_a?(Hash) && data.key?("results")
      return [] unless data.is_a?(Array)

      data.map { |r| r.merge("band" => Smtping.band(r["status"])) }
    end

    # Poll until the job succeeds, then return its results. The block, if any, receives each job status.
    def wait(job_id, timeout: 1800, interval: 5)
      deadline = now + timeout
      delay = interval.to_f
      loop do
        job = get(job_id)
        yield job if block_given?
        status = job["status"].to_s.downcase
        return results(job_id) if status == "succeeded"

        if %w[failed cancelled].include?(status)
          detail = job["errorMessage"].to_s.empty? ? "" : ": #{job['errorMessage']}"
          raise JobFailedError.new("Job #{job_id} #{status}#{detail}", job)
        end
        raise TimeoutError, "Job #{job_id} still running after #{timeout} s" if now + delay > deadline

        sleep(delay)
        delay = [delay * 1.5, 30.0].min
      end
    end

    # Create a job and wait for its results in one call.
    def run(emails, **options, &block)
      job = create(emails)
      wait(job["jobId"], **options, &block)
    end

    private

    def escape(value)
      URI.encode_www_form_component(value.to_s)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
