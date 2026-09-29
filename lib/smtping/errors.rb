# frozen_string_literal: true

module Smtping
  # Base class for every SMTPing error. status is 0 when no HTTP response was received.
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message = nil, status: 0, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  # Missing, invalid or revoked API key (401, 403).
  class AuthenticationError < Error; end
  # Not enough credits (402).
  class InsufficientCreditsError < Error; end
  # Rate limit still exceeded after the automatic retries (429).
  class RateLimitError < Error; end
  # Invalid input, rejected locally or by the API (400, 422).
  class ValidationError < Error; end
  # A request or a bulk wait took longer than allowed.
  class TimeoutError < Error; end

  # A bulk job ended as Failed or Cancelled.
  class JobFailedError < Error
    attr_reader :job

    def initialize(message, job)
      super(message)
      @job = job
    end
  end
end
