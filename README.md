# SMTPing Email Verifier for Ruby

Official Ruby SDK for the [SMTPing](https://smtping.com) email verification API.

- Ruby 2.7 or later, no runtime dependencies
- Automatic retries on rate limits (429) and server errors (5xx)
- Bulk jobs up to 100,000 addresses, with polling built in

## Install

```bash
gem install smtping-email-verifier
```

or in your Gemfile:

```ruby
gem "smtping-email-verifier"
```

Create an API key in the [SMTPing dashboard](https://app.smtping.com). Pass it to the client or set `SMTPING_API_KEY`.

## Verify one address

```ruby
require "smtping"

smtping = Smtping::Client.new # reads SMTPING_API_KEY, or Smtping::Client.new("sk_live_...")

r = smtping.verify("jane@example.com")
puts r["status"], r["band"] # valid, safe
```

Every result carries a `band` for simple routing:

| band | statuses | action |
| --- | --- | --- |
| `safe` | valid, alias | send |
| `avoid` | invalid, spamtrap, disposable, blacklisted, complainer, spambot, inbox_full | remove |
| `judgement` | catch_all, unknown, role and others | your call |

## Verify a list

Small lists with parallel single calls:

```ruby
rows = smtping.verify_many(["a@example.com", "b@example.com"], concurrency: 5)
```

Large lists as one bulk job:

```ruby
job = smtping.bulk.create(emails)
rows = smtping.bulk.wait(job["jobId"]) { |s| puts s["processedEmails"] }

# or in one call
rows = smtping.bulk.run(emails)
sendable = rows.select { |x| x["band"] == "safe" }
```

Check a job later with `bulk.get(job_id)` and `bulk.results(job_id)`.

## Threat list checks

```ruby
trap = smtping.check("spamtrap", "jane@example.com")
puts trap["matched"], trap["source"]
# also: "disposable", "spambot", "complainer"

# up to 1,000 addresses in one call
batch = smtping.check_batch("disposable", emails)
```

## Credits

```ruby
puts smtping.credits["remaining"]
```

## Errors

```ruby
begin
  smtping.verify("jane@example.com")
rescue Smtping::InsufficientCreditsError
  # top up
rescue Smtping::Error => e
  puts e.status, e.message
end
```

Classes: `Smtping::Error` (base, with `status` and `body`), `AuthenticationError`, `InsufficientCreditsError`, `RateLimitError`, `ValidationError`, `JobFailedError`, `TimeoutError`.

## Options

| option | default | |
| --- | --- | --- |
| api key (first argument) | `SMTPING_API_KEY` | required |
| `base_url:` | `https://api.smtping.com/api/v1` | |
| `timeout:` | `60` | seconds, per request |
| `max_retries:` | `3` | network errors, 429, 5xx |

## Links

- [API documentation](https://smtping.com/docs)
- [Pricing](https://smtping.com/pricing)
- Support: support@smtping.com

MIT License
