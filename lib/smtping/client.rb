# frozen_string_literal: true

module Smtping
  # Client for the SMTPing email verification API.
  class Client
    attr_reader :base_url, :timeout, :max_retries, :user_agent, :bulk

    NETWORK_ERRORS = [SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError].freeze

    # api_key defaults to SMTPING_API_KEY. timeout is per request, in seconds.
    def initialize(api_key = nil, base_url: nil, timeout: 60, max_retries: 3, user_agent: nil)
      @api_key = Smtping.first_present(api_key, ENV["SMTPING_API_KEY"])
      raise AuthenticationError, "Missing API key. Pass it to Smtping::Client.new or set SMTPING_API_KEY." unless @api_key

      @base_url = (Smtping.first_present(base_url, ENV["SMTPING_BASE_URL"]) || DEFAULT_BASE_URL).chomp("/")
      @timeout = timeout
      @max_retries = max_retries
      @user_agent = Smtping.first_present(user_agent) || "smtping-ruby/#{VERSION}"
      @bulk = Bulk.new(self)
    end

    # Verify one address. The result carries a ready-made "band".
    def verify(email)
      e = email.to_s.strip
      raise ValidationError, "Email is required" if e.empty?

      with_band(request(:post, "/verify/single", { email: e }))
    end

    # Verify a small list with parallel single calls. Failed addresses come back with status "error".
    def verify_many(emails, concurrency: 5)
      list = Smtping.normalize(emails, valid_only: false)
      results = Array.new(list.size)
      queue = Queue.new
      list.each_with_index { |e, i| queue << [e, i] }
      workers = [[concurrency.to_i, 1].max, [list.size, 1].max].min
      threads = Array.new(workers) do
        Thread.new do
          loop do
            item = begin
              queue.pop(true)
            rescue ThreadError
              nil
            end
            break unless item

            email, i = item
            results[i] = begin
              verify(email)
            rescue Error => e
              { "email" => email, "status" => "error", "statusDescription" => e.message, "band" => "judgement" }
            end
          end
        end
      end
      threads.each(&:join)
      results
    end

    # Look one address up in a threat list: "spamtrap", "disposable", "spambot" or "complainer".
    def check(type, email)
      t = Smtping.check_type!(type)
      e = email.to_s.strip
      { "email" => e, "check" => t }.merge(request(:post, "/checks/#{t}", { email: e }) || {})
    end

    # Look up to 1,000 addresses up in a threat list in one call.
    def check_batch(type, emails)
      t = Smtping.check_type!(type)
      list = Smtping.normalize(emails, valid_only: true)
      raise ValidationError, "No valid email address in the list" if list.empty?
      raise ValidationError, "A batch check accepts up to #{BATCH_MAX} addresses. Use a job above that." if list.size > BATCH_MAX

      request(:post, "/checks/#{t}/batch", { emails: list })
    end

    # Remaining credit balance.
    def credits
      request(:get, "/credits")
    end

    # Low-level call to any endpoint. Retries network errors, 429 and 5xx.
    def request(method, path, body = nil)
      uri = URI(@base_url + path)
      payload = body.nil? ? nil : JSON.generate(body)
      attempt = 0
      loop do
        begin
          res = perform(method, uri, payload)
        rescue Net::OpenTimeout, Net::ReadTimeout, *NETWORK_ERRORS => e
          if attempt < @max_retries
            attempt += 1
            sleep(backoff(attempt))
            next
          end
          raise TimeoutError, "Request timed out after #{@timeout} s" if e.is_a?(Net::OpenTimeout) || e.is_a?(Net::ReadTimeout)

          raise Error, "Network error: #{e.message}"
        end

        status = res.code.to_i
        return parse(res.body) if status.between?(200, 299)

        if (status == 429 || status >= 500) && attempt < @max_retries
          attempt += 1
          retry_after = res["Retry-After"].to_s.strip
          sleep(retry_after.match?(/\A\d+\z/) && retry_after.to_i.positive? ? retry_after.to_i : backoff(attempt))
          next
        end
        raise error_for(status, res.body)
      end
    end

    private

    def perform(method, uri, payload)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.write_timeout = @timeout if http.respond_to?(:write_timeout=)
      req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
      req["X-API-Key"] = @api_key
      req["Accept"] = "application/json"
      req["User-Agent"] = @user_agent
      if payload
        req["Content-Type"] = "application/json"
        req.body = payload
      end
      http.start { |h| h.request(req) }
    end

    def with_band(result)
      r = result.is_a?(Hash) ? result : {}
      r.merge("band" => Smtping.band(r["status"]))
    end

    def parse(text)
      return nil if text.nil? || text.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError
      { "raw" => text }
    end

    def error_for(status, body)
      data = begin
        JSON.parse(body.to_s)
      rescue JSON::ParserError
        nil
      end
      message = nil
      if data.is_a?(Hash)
        message = data["error"] if data["error"].is_a?(String)
        message ||= data["message"] if data["message"].is_a?(String)
      end
      message ||= "SMTPing API returned HTTP #{status}"
      klass = case status
              when 401, 403 then AuthenticationError
              when 402 then InsufficientCreditsError
              when 429 then RateLimitError
              when 400, 422 then ValidationError
              else Error
              end
      klass.new(message, status: status, body: body)
    end

    def backoff(attempt)
      [2**(attempt - 1), 15].min + (rand * 0.25)
    end
  end
end
