namespace :phone_analysis do
  desc "Run enhanced phone analysis for all customers with phone numbers"
  task :bulk_analyze, [:batch_size, :force] => :environment do |task, args|
    batch_size = args[:batch_size]&.to_i || 50
    force_reanalyze = args[:force] == 'true'
    
    puts "Starting bulk phone analysis..."
    puts "Batch size: #{batch_size}"
    puts "Force reanalyze: #{force_reanalyze}"
    
    BulkPhoneAnalysisWorker.perform_async(batch_size, force_reanalyze)
    puts "Bulk phone analysis job has been queued."
  end

  desc "Analyze a specific customer's phone number"
  task :analyze_customer, [:customer_id] => :environment do |task, args|
    customer_id = args[:customer_id]&.to_i
    
    unless customer_id
      puts "Usage: rails phone_analysis:analyze_customer[CUSTOMER_ID]"
      exit 1
    end
    
    customer = Customer.find_by(id: customer_id)
    unless customer
      puts "Customer with ID #{customer_id} not found."
      exit 1
    end
    
    unless customer.phone.present?
      puts "Customer #{customer_id} (#{customer.name}) has no phone number."
      exit 1
    end
    
    puts "Analyzing phone number for customer #{customer_id} (#{customer.name}): #{customer.phone}"
    
    # Run analysis synchronously for immediate feedback
    phone_service = PhoneLocationService.new(customer.phone)
    result = phone_service.analyze
    
    if result[:success]
      customer.update_from_phone_analysis(result)
      puts "✓ Analysis completed successfully!"
      puts "Results:"
      puts "  Country: #{result[:data][:country_name]} (#{result[:data][:country]})"
      puts "  State: #{result[:data][:state]}"
      puts "  City: #{result[:data][:city]}"
      puts "  Area Code: #{result[:data][:area_code]}"
      puts "  Timezone: #{result[:data][:timezone]}"
      puts "  Preferred Calling Time: #{result[:data][:preferred_calling_time]}"
      puts "  Carrier: #{result[:data][:carrier]}"
      puts "  Phone Type: #{result[:data][:phone_type]}"
      if result[:data][:coordinates]
        puts "  Coordinates: #{result[:data][:coordinates][:lat]}, #{result[:data][:coordinates][:lng]}"
      end
    else
      puts "✗ Analysis failed: #{result[:error]}"
    end
  end

  desc "Show phone analysis statistics"
  task :stats => :environment do
    total_customers = Customer.count
    customers_with_phone = Customer.where.not(phone: [nil, '']).count
    analyzed_customers = Customer.where.not(phone_analysis_completed_at: nil).count
    failed_analysis = Customer.where(phone_analysis_version: '1.0_failed').count
    
    puts "Phone Analysis Statistics:"
    puts "=" * 50
    puts "Total customers: #{total_customers}"
    puts "Customers with phone numbers: #{customers_with_phone}"
    puts "Successfully analyzed: #{analyzed_customers - failed_analysis}"
    puts "Failed analysis: #{failed_analysis}"
    puts "Pending analysis: #{customers_with_phone - analyzed_customers}"
    puts ""
    
    if analyzed_customers > 0
      # Show breakdown by country
      country_stats = Customer.where.not(phone_analysis_completed_at: nil)
                             .where.not(country: [nil, ''])
                             .group(:country)
                             .count
                             
      puts "Analysis by Country:"
      puts "-" * 30
      country_stats.sort_by { |_, count| -count }.first(10).each do |country, count|
        puts "  #{country}: #{count}"
      end
      puts ""
      
      # Show timezone distribution
      timezone_stats = Customer.where.not(phone_analysis_completed_at: nil)
                              .where.not(timezone: [nil, ''])
                              .group(:timezone)
                              .count
                              
      puts "Analysis by Timezone:"
      puts "-" * 30
      timezone_stats.sort_by { |_, count| -count }.first(10).each do |timezone, count|
        puts "  #{timezone}: #{count}"
      end
    end
  end

  desc "Test phone analysis with a specific phone number"
  task :test, [:phone_number] => :environment do |task, args|
    phone_number = args[:phone_number]
    
    unless phone_number
      puts "Usage: rails phone_analysis:test['+1234567890']"
      exit 1
    end
    
    puts "Testing phone number analysis for: #{phone_number}"
    puts "=" * 50
    
    phone_service = PhoneLocationService.new(phone_number)
    
    # Test basic validity
    puts "Valid: #{phone_service.valid?}"
    puts "Possible: #{phone_service.possible?}"
    puts ""
    
    # Run full analysis
    result = phone_service.analyze
    
    if result[:success]
      data = result[:data]
      
      puts "Analysis Results:"
      puts "-" * 30
      puts "Formatted Number: #{data[:formatted_number]}"
      puts "National Format: #{data[:national_format]}"
      puts "Country Code: #{data[:country_code]}"
      puts "Area Code: #{data[:area_code]}"
      puts "Phone Type: #{data[:phone_type]}"
      puts ""
      puts "Geographic Information:"
      puts "Country: #{data[:country_name]} (#{data[:country]})"
      puts "State: #{data[:state] || 'N/A'}"
      puts "City: #{data[:city] || 'N/A'}"
      puts "Geo Name: #{data[:geo_name] || 'N/A'}"
      if data[:coordinates]
        puts "Coordinates: #{data[:coordinates][:lat]}, #{data[:coordinates][:lng]}"
      end
      puts ""
      puts "Timezone Information:"
      puts "Timezone: #{data[:timezone]}"
      puts "Timezone Name: #{data[:timezone_name]}"
      puts "Timezone Offset: #{data[:timezone_offset]} hours"
      puts "Preferred Calling Time: #{data[:preferred_calling_time]}"
      puts ""
      puts "Carrier Information:"
      puts "Carrier: #{data[:carrier] || 'N/A'}"
      puts "Line Type: #{data[:line_type] || 'N/A'}"
    else
      puts "✗ Analysis failed: #{result[:error]}"
    end
  end

  desc "Migrate from old to new phone analysis system"
  task :migrate_from_gemini => :environment do
    puts "Migrating customers from Gemini-based to PhoneLib-based analysis..."
    
    # Find customers that were analyzed with the old system but don't have the new analysis
    customers = Customer.where(phone_analysis_completed_at: nil)
                       .where.not(phone: [nil, ''])
                       .where.not(preferred_calling_time: [nil, '', 'Not Applicable'])
    
    count = customers.count
    puts "Found #{count} customers to migrate."
    
    if count > 0
      BulkPhoneAnalysisWorker.perform_async(50, false)
      puts "Migration job has been queued."
    else
      puts "No customers need migration."
    end
  end
end