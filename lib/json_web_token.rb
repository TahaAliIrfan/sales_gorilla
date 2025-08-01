class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    raise "SECRET_KEY_BASE not configured" if SECRET_KEY.blank?
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    raise "SECRET_KEY_BASE not configured" if SECRET_KEY.blank?
    raise "Token is blank" if token.blank?
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new decoded
  end
end