# View helpers for the Relay Outreach workspace (Phase 7). Maps the app's real
# campaign + execution statuses onto the relay design's badges and segmented
# progress bar (docs/design/relay-app/project/app/view-outreach.jsx).
module OutreachHelper
  # Campaign status → { badge:, label:, icon: } for the status pill. Keys are the
  # app's Campaign::STATUSES (draft/scheduled/in_progress/completed/failed/stopped).
  CAMPAIGN_STATUS_META = {
    "draft"       => { badge: "rl-badge--neutral", label: "Draft",       icon: "file" },
    "scheduled"   => { badge: "rl-badge--neutral", label: "Scheduled",   icon: "clock" },
    "in_progress" => { badge: "rl-badge--info",    label: "Sending",     icon: "loader" },
    "completed"   => { badge: "rl-badge--success", label: "Completed",   icon: "check-circle-2" },
    "failed"      => { badge: "rl-badge--danger",  label: "Failed",      icon: "alert-circle" },
    "stopped"     => { badge: "rl-badge--warning", label: "Stopped",     icon: "square" }
  }.freeze

  def outreach_campaign_status_meta(status)
    CAMPAIGN_STATUS_META.fetch(status, CAMPAIGN_STATUS_META["draft"])
  end

  # Segments of the per-recipient progress bar, mapped to the three real
  # execution buckets the controller produces. Order = stacking order.
  SEND_SEGMENTS = [
    { key: :completed, label: "Sent",    color: "var(--channel-whatsapp)" },
    { key: :pending,   label: "Pending", color: "var(--color-border-strong)" },
    { key: :failed,    label: "Failed",  color: "var(--color-danger)" }
  ].freeze

  # Renders a template body with {{var}} placeholders as inline rl-badge chips,
  # mirroring the prototype's body preview. Escapes the surrounding text.
  def outreach_template_preview(body)
    return "" if body.blank?

    safe_join(
      body.split(/(\{\{[^}]+\}\})/).map do |part|
        if part =~ /\A\{\{(.+)\}\}\z/
          tag.span(Regexp.last_match(1).strip, class: "rl-badge rl-badge--primary", style: "height:18px;margin:0 1px")
        else
          part
        end
      end
    )
  end
end
