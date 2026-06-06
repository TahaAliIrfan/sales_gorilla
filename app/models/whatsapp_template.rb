# Approved WhatsApp Content templates synced from Twilio's Content API.
# Used to send messages outside the 24h freeform reply window.
class WhatsappTemplate < ApplicationRecord
  validates :content_sid, presence: true, uniqueness: true

  scope :approved, -> { where(approval_status: 'approved') }
  scope :ordered,  -> { order(Arel.sql('LOWER(friendly_name) ASC')) }

  # Variable placeholder names declared in the template. Twilio stores them as
  # a Hash like { "1" => "default", "name" => "Customer" }. Numeric keys are
  # sorted numerically; named keys follow alphabetically.
  def variable_keys
    return [] if variables.blank?
    numeric, named = variables.keys.partition { |k| k.to_s =~ /\A\d+\z/ }
    numeric.sort_by { |k| k.to_i } + named.sort
  end

  def variable_count
    variable_keys.size
  end

  # Renders the template body with the supplied variables substituted in.
  # Used purely for previewing the outgoing message in the chat thread —
  # Twilio does the real substitution on its side via content_variables.
  def render_body(values = {})
    rendered = body.to_s.dup
    variable_keys.each do |k|
      val = values[k].presence || values[k.to_i].presence || "{{#{k}}}"
      rendered.gsub!("{{#{k}}}", val.to_s)
    end
    rendered
  end

  # True if this template includes a media attachment (twilio/media type).
  def has_media?
    media_definition.present?
  end

  # True if the user must supply a file at send time — i.e. the media URL
  # contains at least one variable placeholder (e.g. `"media": ["{{1}}"]`).
  # When the URL is hardcoded, Twilio already knows the file and no upload
  # is needed.
  def requires_media_upload?
    has_media? && media_variable_keys.any?
  end

  # Variable keys referenced inside the media URL field, e.g. if the template
  # defines `"media": ["{{1}}"]` this returns ["1"]. Those variable slots must
  # be filled with a publicly-fetchable file URL when sending.
  def media_variable_keys
    urls = Array(media_definition&.dig('media'))
    return [] if urls.empty?

    urls.flat_map { |u| u.to_s.scan(/\{\{(\w+)\}\}/).flatten }.uniq
  end

  # Variable keys that are NOT media variables — i.e. plain-text placeholders
  # the user types a value into.
  def text_variable_keys
    variable_keys - media_variable_keys
  end

  private

  def media_definition
    return nil if types.blank?
    types['twilio/media'].is_a?(Hash) ? types['twilio/media'] : nil
  end
end
