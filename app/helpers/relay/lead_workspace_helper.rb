# Presentation helpers for the Relay lead workspace (customers#show).
# Display-only mappings that keep view-lead.jsx's voice — sentence case,
# mono/tabular times, no emoji — while reading straight from the DB.
module Relay
  module LeadWorkspaceHelper
    # Day chip label for a date separator, relative where it reads naturally.
    def relay_conv_day_label(date)
      today = Date.current
      case date
      when today        then "Today"
      when today - 1    then "Yesterday"
      else
        date.year == today.year ? date.strftime("%A, %b %-d") : date.strftime("%b %-d, %Y")
      end
    end

    # Tabular time-of-day for a bubble/card (e.g. "09:41").
    def relay_conv_time(time)
      return "" if time.blank?
      time.in_time_zone(Time.zone).strftime("%H:%M")
    end

    # WhatsApp delivery state -> read-receipt rendering. Mirrors the prototype's
    # check-check glyph that turns teal once read.
    def relay_whatsapp_read?(message)
      message.status.to_s.downcase.in?(%w[read delivered])
    end

    # Seconds -> "M:SS" for the call player, matching the prototype's duration.
    def relay_call_duration(seconds)
      secs = seconds.to_i
      format("%d:%02d", secs / 60, secs % 60)
    end

    # A short, human outcome badge for a call card from its duration.
    def relay_call_outcome(recording)
      secs = recording.duration.to_i
      if secs >= 60 then "Connected"
      elsif secs.positive? then "Brief"
      else "No answer"
      end
    end

    def relay_call_outcome_variant(recording)
      recording.duration.to_i >= 60 ? "rl-badge--success" : "rl-badge--neutral"
    end

    # Maps a CustomerActivity to the system micro-event icon used on the canvas.
    def relay_activity_icon(action)
      case action.to_s
      when /call/i              then "phone"
      when /status/i            then "tag"
      when /user|assign/i       then "user-check"
      when /follow/i            then "calendar-plus"
      when /score/i             then "sparkles"
      when /cost estimate/i     then "calculator"
      when /proposal/i          then "file-text"
      else "activity"
      end
    end

    # Human one-liner for a system micro-event.
    def relay_activity_text(activity)
      base = activity.action.to_s.humanize
      activity.details.present? ? "#{base} — #{activity.details}" : base
    end

    # Email preview line under the subject.
    def relay_email_body(email)
      email.body_text.presence || ActionView::Base.full_sanitizer.sanitize(email.body_html.to_s).to_s.strip
    end
  end
end
