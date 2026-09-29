# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"
require_relative "smtping/version"
require_relative "smtping/errors"
require_relative "smtping/client"
require_relative "smtping/bulk"

# Official Ruby SDK for the SMTPing email verification API.
module Smtping
  DEFAULT_BASE_URL = "https://api.smtping.com/api/v1"
  BULK_MAX = 100_000
  BATCH_MAX = 1_000
  CHECKS = %w[spamtrap disposable spambot complainer].freeze
  SAFE = %w[valid alias].freeze
  AVOID = %w[invalid spamtrap disposable blacklisted complainer spambot inbox_full].freeze
  EMAIL_RE = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/.freeze

  # "safe" (send), "avoid" (remove) or "judgement" (your call).
  def self.band(status)
    return "safe" if SAFE.include?(status)
    return "avoid" if AVOID.include?(status)

    "judgement"
  end

  def self.email?(value)
    EMAIL_RE.match?(value.to_s.strip)
  end

  def self.normalize(emails, valid_only:)
    Array(emails).map { |e| e.to_s.strip.downcase }
                 .reject(&:empty?)
                 .select { |e| !valid_only || email?(e) }
                 .uniq
  end

  def self.check_type!(type)
    t = type.to_s.strip.downcase
    raise ValidationError, "Unknown check \"#{type}\". Use one of: #{CHECKS.join(', ')}" unless CHECKS.include?(t)

    t
  end

  def self.first_present(*values)
    values.map { |v| v.to_s.strip }.find { |v| !v.empty? }
  end
end
