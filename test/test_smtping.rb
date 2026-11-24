# frozen_string_literal: true

require "minitest/autorun"
require "smtping-email-verifier"

class SmtpingTest < Minitest::Test
  # A client whose HTTP calls answer from a table, or with one body.
  def client(body)
    c = Smtping::Client.new("sk_test")
    c.define_singleton_method(:request) { |_method, path, *_rest| body.is_a?(Proc) ? body.call(path) : body }
    c
  end

  def band(row)
    client(row).verify("a@example.com")["band"]
  end

  # The band of the API wins; the status is only the fallback.
  def test_single
    assert_equal "judgement", band({ "status" => "valid", "band" => "judgement" })
    assert_equal "safe", band({ "status" => "valid" })
    assert_equal "safe", band({ "status" => "valid", "band" => "other" })
    assert_equal "avoid", band({ "status" => "no_reply" })
  end

  def test_bulk
    rows = [{ "status" => "valid", "band" => "judgement" }, { "status" => "no_reply" }]
    c = client(->(path) { path.end_with?("/result") ? rows : { "jobId" => "j1", "status" => "Succeeded" } })
    assert_equal %w[judgement avoid], c.bulk.run(["a@example.com", "b@example.com"]).map { |r| r["band"] }
  end

  def test_many
    assert_equal %w[judgement judgement], client({ "status" => "valid", "band" => "judgement" }).verify_many(%w[a@example.com b@example.com]).map { |r| r["band"] }
  end

  def test_fallback
    expected = { "valid" => "safe", "alias" => "safe", "invalid" => "avoid", "spamtrap" => "avoid", "catchall" => "judgement", "unknown" => "judgement", nil => "judgement" }
    expected.each { |status, want| assert_equal want, Smtping.band(status) }
  end

  def test_errors
    assert_raises(Smtping::ValidationError) { client({}).verify(" ") }
    assert_raises(Smtping::ValidationError) { client({}).check("nope", "a@example.com") }
  end
end
