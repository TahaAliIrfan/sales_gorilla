namespace :lead_scoring do
  desc "Calculate lead scores for all customers"
  task calculate_all: :environment do
    puts "Starting lead score calculation for all customers..."
    
    total_customers = Customer.count
    puts "Total customers to process: #{total_customers}"
    
    LeadScoringWorker.perform_async
    
    puts "Lead scoring job has been queued for all customers"
    puts "Check Sidekiq dashboard at /sidekiq to monitor progress"
  end
  
  desc "Calculate lead scores for customers without scores"
  task calculate_missing: :environment do
    puts "Starting lead score calculation for customers without scores..."
    
    customers_without_scores = Customer.where(lead_score: nil)
    total_customers = customers_without_scores.count
    puts "Total customers without scores: #{total_customers}"
    
    if total_customers > 0
      customers_without_scores.find_each(batch_size: 100) do |customer|
        LeadScoringWorker.perform_async(customer.id)
      end
      
      puts "#{total_customers} lead scoring jobs have been queued"
      puts "Check Sidekiq dashboard at /sidekiq to monitor progress"
    else
      puts "All customers already have lead scores!"
    end
  end
  
  desc "Recalculate lead scores for all customers (force update)"
  task recalculate_all: :environment do
    puts "Starting lead score recalculation for all customers (force update)..."
    
    total_customers = Customer.count
    puts "Total customers to process: #{total_customers}"
    
    Customer.find_each(batch_size: 100) do |customer|
      LeadScoringWorker.perform_async(customer.id)
    end
    
    puts "#{total_customers} lead scoring jobs have been queued"
    puts "Check Sidekiq dashboard at /sidekiq to monitor progress"
  end
  
  desc "Show lead score statistics"
  task stats: :environment do
    puts "Lead Score Statistics"
    puts "=" * 50
    
    total_customers = Customer.count
    scored_customers = Customer.where.not(lead_score: nil).count
    unscored_customers = total_customers - scored_customers
    
    puts "Total customers: #{total_customers}"
    puts "Customers with scores: #{scored_customers}"
    puts "Customers without scores: #{unscored_customers}"
    puts
    
    if scored_customers > 0
      avg_score = Customer.where.not(lead_score: nil).average(:lead_score).round(2)
      max_score = Customer.maximum(:lead_score)
      min_score = Customer.minimum(:lead_score)
      
      puts "Score Statistics:"
      puts "Average score: #{avg_score}"
      puts "Highest score: #{max_score}"
      puts "Lowest score: #{min_score}"
      puts
      
      # Score distribution
      excellent = Customer.where(lead_score: 80..100).count
      good = Customer.where(lead_score: 60..79).count
      fair = Customer.where(lead_score: 40..59).count
      poor = Customer.where(lead_score: 20..39).count
      very_poor = Customer.where(lead_score: 0..19).count
      
      puts "Score Distribution:"
      puts "Excellent (80-100): #{excellent} customers"
      puts "Good (60-79): #{good} customers"
      puts "Fair (40-59): #{fair} customers"
      puts "Poor (20-39): #{poor} customers"
      puts "Very Poor (0-19): #{very_poor} customers"
      puts
      
      # Top countries by average score
      puts "Top 10 Countries by Average Score:"
      top_countries = Customer.where.not(lead_score: nil, country: [nil, ''])
                             .group(:country)
                             .average(:lead_score)
                             .sort_by { |_, score| -score }
                             .first(10)
      
      top_countries.each_with_index do |(country, avg_score), index|
        count = Customer.where(country: country).count
        puts "#{index + 1}. #{country}: #{avg_score.round(2)} (#{count} customers)"
      end
    end
  end
  
  desc "Show top scoring customers"
  task top_customers: :environment do
    puts "Top 20 Customers by Lead Score"
    puts "=" * 50
    
    top_customers = Customer.where.not(lead_score: nil)
                           .order(lead_score: :desc)
                           .limit(20)
    
    if top_customers.any?
      top_customers.each_with_index do |customer, index|
        puts "#{index + 1}. #{customer.name} (#{customer.company}) - Score: #{customer.lead_score}"
        puts "   Country: #{customer.country || 'N/A'}"
        puts "   Description: #{customer.idea_description.present? ? 'Yes' : 'No'}"
        puts "   Updated: #{customer.lead_score_updated_at&.strftime('%b %d, %Y')}"
        puts
      end
    else
      puts "No customers have been scored yet."
      puts "Run 'rake lead_scoring:calculate_all' to calculate scores."
    end
  end
end