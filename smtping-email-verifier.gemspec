# frozen_string_literal: true

require_relative "lib/smtping/version"

Gem::Specification.new do |s|
  s.name = "smtping-email-verifier"
  s.version = Smtping::VERSION
  s.summary = "SMTPing Email Verifier: official Ruby SDK for the SMTPing email verification API"
  s.description = "Verify one email address or a list of 100,000, flag spamtraps, complainers, spambots and disposable addresses. " \
                  "Automatic retries on 429 and 5xx, bulk polling built in, no runtime dependencies."
  s.authors = ["SMTPing"]
  s.email = "support@smtping.com"
  s.homepage = "https://smtping.com/docs#sdks"
  s.license = "MIT"
  s.files = Dir["lib/**/*.rb"] + %w[README.md LICENSE]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 2.7"
  s.metadata = {
    "homepage_uri" => "https://smtping.com",
    "documentation_uri" => "https://smtping.com/docs#sdks",
    "source_code_uri" => "https://github.com/smtping/smtping-ruby",
    "bug_tracker_uri" => "https://github.com/smtping/smtping-ruby/issues"
  }
end
