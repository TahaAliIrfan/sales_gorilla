# Presentation helpers for Relay Insights (Phase 8). Display-only delta math
# for the KPI tiles — every delta compares the selected window to the
# immediately-preceding equal-length window computed in the controller.
module ReportsHelper
  # Percent change between two magnitudes, rounded to a whole percent.
  # Returns nil when there's no prior data to compare against (so the tile shows
  # an honest "no prior data" instead of a fake +100%).
  def relay_pct_delta(current, previous)
    return nil if previous.to_f.zero?
    (((current.to_f - previous) / previous) * 100).round
  end

  # Difference in percentage points (for rates like conversion), rounded.
  # Always comparable, so this never returns nil.
  def relay_point_delta(current, previous)
    (current.to_f - previous.to_f).round
  end
end
