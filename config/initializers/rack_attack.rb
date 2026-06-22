# frozen_string_literal: true

# Rack::Attack throttles abusive traffic. It was added after a burst of ~240
# bot signups hit the public /signup form (random names, gmail dot-trick
# emails, never confirmed). We throttle the auth endpoints only — NOT a global
# per-IP limit — so inbound webhooks (Meta lead ads, Zapier) are never affected.
class Rack::Attack
  # Share counters across all Puma workers via Redis (same instance Sidekiq
  # uses). Falls back to the default in-memory store if Redis is unavailable,
  # which still throttles per-process rather than not at all.
  begin
    redis_url = Rails.application.credentials.dig(:redis, :production_url) ||
                ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: redis_url, namespace: "rack_attack", error_handler: ->(*) {}
    )
  rescue StandardError => e
    Rails.logger.warn("[Rack::Attack] Redis store unavailable, using default cache: #{e.message}")
  end

  ### Throttles ###

  # New-account creation — the spam target. Hard cap per IP.
  throttle("signup/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/signup"
  end

  # Sign-in attempts per IP (credential stuffing / brute force).
  throttle("login/ip", limit: 15, period: 5.minutes) do |req|
    req.ip if req.post? && req.path == "/signin"
  end

  # Sign-in attempts targeting a single account, regardless of source IP.
  throttle("login/email", limit: 10, period: 1.hour) do |req|
    if req.post? && req.path == "/signin"
      begin
        req.params.dig("user", "email").to_s.downcase.strip.presence
      rescue StandardError
        nil
      end
    end
  end

  # Password-reset requests per IP.
  throttle("password-reset/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/password"
  end

  # Email-confirmation resends per IP.
  throttle("confirmation/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/confirmation"
  end

  ### Response for throttled requests ###
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      ["Too many requests. Please wait a moment and try again.\n"]
    ]
  end
end

# Log throttled requests so abuse is visible in the Rails log.
ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[Rack::Attack] throttled #{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}")
end
