# Presentation helpers for the Relay "Today" dashboard. Display-only:
# initials, deterministic avatar colour class, priority pill mapping, and
# human due-date labels mirroring docs/design/relay-app/project/app/view-today.jsx.
module UserDashboardHelper
  AVATAR_CLASSES = %w[rl-avatar--c1 rl-avatar--c2 rl-avatar--c3 rl-avatar--c4 rl-avatar--c5].freeze

  PRIORITY_PILL = {
    "High"   => { dot: "var(--color-danger)",  label: "High" },
    "Medium" => { dot: "var(--color-warning)", label: "Medium" },
    "Low"    => { dot: "var(--color-fg-4)",    label: "Low" }
  }.freeze

  def relay_initials(name)
    parts = name.to_s.strip.split(/\s+/)
    return "?" if parts.empty?
    (parts.first[0].to_s + (parts.length > 1 ? parts.last[0].to_s : "")).upcase
  end

  # Stable avatar colour from the record's name so it doesn't flicker per render.
  def relay_avatar_class(name)
    AVATAR_CLASSES[name.to_s.bytes.sum % AVATAR_CLASSES.length]
  end

  def relay_priority_pill(priority)
    PRIORITY_PILL[priority] || PRIORITY_PILL["Low"]
  end

  # Human label for a task due date relative to today, tabular times in mono.
  def relay_due_label(due_date)
    return "No due date" if due_date.blank?
    date = due_date.to_date
    today = Date.current
    time = due_date.strftime("%-I:%M %p")
    if date < today
      days = (today - date).to_i
      days == 1 ? "Yesterday" : "#{days} days ago"
    elsif date == today
      "Today, #{time}"
    elsif date == today + 1
      "Tomorrow, #{time}"
    else
      due_date.strftime("%b %-d, %-I:%M %p")
    end
  end

  # Compact money for stat tiles: $12.5k / $1.2M, matching the prototype's moneyK.
  def relay_money_compact(amount)
    n = amount.to_f
    if n.abs >= 1_000_000
      "$#{(n / 1_000_000).round(1)}M"
    elsif n.abs >= 1_000
      "$#{(n / 1_000).round(1)}k"
    else
      "$#{n.round}"
    end
  end

  # Derived monthly revenue target for attainment bars. No revenue-target field
  # exists on User, so we derive a stable org-wide target from the org's average
  # won-deal value (avg × 4 ≈ a month of closes). Shared by the Today dashboard
  # (Phase 2) and Insights (Phase 8) so the attainment math stays consistent.
  # Cached per-request via the passed memo hash to avoid re-querying per rep.
  def relay_monthly_target(memo = {})
    memo[:org_target] ||= begin
      avg = Deal.won.average(:amount).to_f
      avg.positive? ? (avg * 4).round : 100_000
    end
  end

  # Attainment as a capped 0–100 percentage of the derived monthly target.
  def relay_attainment_pct(won_value, target)
    return 0 unless target.positive?
    [ ((won_value.to_f / target) * 100).round, 100 ].min
  end

  def relay_attainment_color(pct)
    if pct >= 85 then "var(--color-success)"
    elsif pct >= 60 then "var(--color-warning)"
    else "var(--color-danger)"
    end
  end

  def relay_attainment_text_color(pct)
    if pct >= 85 then "var(--color-success-text)"
    elsif pct >= 60 then "var(--color-warning-text)"
    else "var(--color-danger-text)"
    end
  end
end
