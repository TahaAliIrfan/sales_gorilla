module DashboardHelper
  # Calculate percentage and handle division by zero
  def calculate_percentage(numerator, denominator)
    denominator.to_i > 0 ? (numerator.to_f / denominator * 100).round(2) : 0
  end
end
