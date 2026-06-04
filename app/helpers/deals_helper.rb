module DealsHelper
  # Full money, mono numerals, no cents — matches the prototype's RX.money used
  # on deal cards and the drawer (docs/design/relay-app/project/app/view-pipeline.jsx).
  def relay_money(amount)
    number_to_currency(amount.to_f, precision: 0)
  end

  # Deterministic stage colour for the column dot / drawer pill. Stages have no
  # stored colour in this DB, so derive a stable swatch from the stage name —
  # except the implicit won/lost stages which read success/danger.
  RELAY_STAGE_SWATCHES = %w[
    var(--cat-1) var(--cat-2) var(--cat-3) var(--cat-4) var(--cat-5) var(--cat-6)
  ].freeze

  def relay_stage_color(stage)
    name = stage.respond_to?(:name) ? stage.name.to_s : stage.to_s
    case name.downcase
    when /won/ then "var(--color-success)"
    when /lost/ then "var(--color-danger)"
    else RELAY_STAGE_SWATCHES[name.bytes.sum % RELAY_STAGE_SWATCHES.length]
    end
  end

  # Whole-day age of a deal since creation, for the card foot ("12d old").
  def relay_deal_age(deal)
    return 0 unless deal.created_at
    ((Time.current - deal.created_at) / 1.day).floor
  end

  # Pill class for a deal's win/loss status.
  def relay_deal_status_pill(status)
    case status.to_s
    when "won" then "rl-pill--success"
    when "lost" then "rl-pill--danger"
    else "rl-pill--info"
    end
  end

  # Map a DealActivity#action to a timeline icon + dot tint, mirroring the
  # prototype audit-trail glyphs.
  def relay_activity_icon(action)
    case action.to_s
    when "deal_created" then [ "flag", "brand" ]
    when "stage_update" then [ "arrow-right", "" ]
    when "user_assignment" then [ "user-check", "" ]
    when "status_update" then [ "trophy", "success" ]
    when "field_update" then [ "file-text", "" ]
    else [ "circle", "" ]
    end
  end
end
