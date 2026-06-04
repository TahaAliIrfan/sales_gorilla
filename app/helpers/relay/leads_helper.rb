#
# Helpers for the Relay Leads list. Map real Customer statuses to the DS pill
# variants (.rl-pill--*) and lead_score to the meter color, mirroring the
# prototype's RX.STATUS / scoreColor (docs/design/relay-app/project/app/data.jsx).
module Relay
  module LeadsHelper
    # customer_status taxonomy value -> DS pill modifier class.
    # Keys off the status STRING; unknown/new taxonomy values fall back to the
    # neutral pill via the else branch.
    def relay_status_pill_class(status)
      case status.to_s
      when "Converted"            then "rl-pill--success"
      when "Contact Established"  then "rl-pill--brand"
      when "Proposal Sent"        then "rl-pill--warning"
      when "Lead", "Pending"      then "rl-pill--info"
      when "Not Interested", "Invalid", "Exhausted", "Exhausted_1",
           "Unresponsive", "Contact Not Established"
        "rl-pill--danger"
      else "" # Retarget and any others fall back to the neutral pill
      end
    end

    # Lead score (0–100) -> meter fill color. Mirrors RX.scoreColor.
    def relay_score_color(score)
      score = score.to_i
      if score >= 75 then "var(--color-success)"
      elsif score >= 50 then "var(--color-warning)"
      elsif score >= 25 then "var(--cat-3)"
      else "var(--color-danger)"
      end
    end

    # Source tag dot color, cycled across the categorical palette so distinct
    # lead sources read as distinct chips.
    def relay_source_color(source)
      palette = %w[
        var(--cat-1) var(--cat-2) var(--cat-3) var(--cat-4)
        var(--cat-5) var(--cat-6) var(--cat-7) var(--cat-8)
      ]
      palette[source.to_s.sum % palette.size]
    end
  end
end
