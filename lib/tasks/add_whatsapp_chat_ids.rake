namespace :customers do
  desc "Add WhatsApp chat IDs to customers in the format <countrycode_short>@c.us"
  task add_whatsapp_chat_ids: :environment do
    puts "Starting to add WhatsApp chat IDs to customers..."
    
    # Keep track of processed customers
    total_customers = Customer.count
    updated_count = 0
    skipped_count = 0
    failed_count = 0
    
    # Process each customer
    Customer.find_each do |customer|
      begin
        if customer.phone.present?
          # Extract the phone number without the + sign
          # The format should be like 491234567890@c.us
          phone_without_plus = customer.phone.gsub(/\A\+/, '')
          
          # Create WhatsApp chat ID in the required format
          whatsapp_chat_id = "#{phone_without_plus}@c.us"
          
          # Update the customer record
          customer.update!(whatsapp_chat_id: whatsapp_chat_id)
          
          # Log the update
          puts "Updated customer #{customer.id} (#{customer.name}): #{customer.phone} -> #{whatsapp_chat_id}"
          updated_count += 1
        else
          puts "Skipped customer #{customer.id} (#{customer.name}): No phone number available"
          skipped_count += 1
        end
      rescue => e
        puts "Failed to update customer #{customer.id} (#{customer.name}): #{e.message}"
        failed_count += 1
      end
    end
    
    # Output summary
    puts "\nSummary:"
    puts "Total customers: #{total_customers}"
    puts "Updated: #{updated_count}"
    puts "Skipped (no phone): #{skipped_count}"
    puts "Failed: #{failed_count}"
    puts "\nTask completed!"
  end

  desc "Synchronize missing WhatsApp chat IDs for customers with phone numbers"
  task sync_missing_whatsapp_chat_ids: :environment do
    puts "Starting to synchronize missing WhatsApp chat IDs..."
    
    # Find customers with phone numbers but no WhatsApp chat ID
    customers_to_update = Customer.where.not(phone: [nil, '']).where(whatsapp_chat_id: [nil, ''])
    
    total_to_update = customers_to_update.count
    updated_count = 0
    failed_count = 0
    
    puts "Found #{total_to_update} customers with phone numbers but no WhatsApp chat ID"
    
    # Process each customer
    customers_to_update.find_each do |customer|
      begin
        # Extract the phone number without the + sign
        phone_without_plus = customer.phone.gsub(/\A\+/, '')
        
        # Create WhatsApp chat ID in the required format
        whatsapp_chat_id = "#{phone_without_plus}@c.us"
        
        # Update the customer record
        customer.update!(whatsapp_chat_id: whatsapp_chat_id)
        
        # Log the update
        puts "Updated customer #{customer.id} (#{customer.name}): #{customer.phone} -> #{whatsapp_chat_id}"
        updated_count += 1
      rescue => e
        puts "Failed to update customer #{customer.id} (#{customer.name}): #{e.message}"
        failed_count += 1
      end
    end
    
    # Output summary
    puts "\nSummary:"
    puts "Total customers needing update: #{total_to_update}"
    puts "Successfully updated: #{updated_count}"
    puts "Failed: #{failed_count}"
    puts "\nTask completed!"
  end
  
  desc "Add WhatsApp chat ID auto-sync callback to Customer model"
  task setup_whatsapp_chat_id_sync: :environment do
    puts "Setting up WhatsApp chat ID synchronization..."
    
    # Step 1: Generate migration for adding an index to whatsapp_chat_id if it doesn't exist
    migration_name = "add_index_to_whatsapp_chat_id"
    
    if ActiveRecord::Base.connection.index_exists?(:customers, :whatsapp_chat_id)
      puts "Index on whatsapp_chat_id already exists. Skipping migration."
    else
      puts "Generating migration to add index to whatsapp_chat_id..."
      
      # Show command that would be run (user needs to run this themselves)
      puts "\nRun the following command to generate the migration:"
      puts "rails g migration #{migration_name} whatsapp_chat_id:index"
      
      puts "\nAfter generating the migration, make sure it contains:"
      puts "def change"
      puts "  add_index :customers, :whatsapp_chat_id"
      puts "end"
    end
    
    # Step 2: Provide code to add to Customer model for sync functionality
    puts "\nTo automatically sync WhatsApp chat IDs, add this code to app/models/customer.rb:"
    puts "```ruby"
    puts "# Add this with the other before_* callbacks"
    puts "before_save :sync_whatsapp_chat_id, if: -> { phone_changed? && phone.present? }"
    puts ""
    puts "# Add this with the other private methods"
    puts "private"
    puts ""
    puts "def sync_whatsapp_chat_id"
    puts "  # Format the phone number for WhatsApp chat ID"
    puts "  phone_without_plus = phone.gsub(/\\A\\+/, '')"
    puts "  self.whatsapp_chat_id = \"\#{phone_without_plus}@c.us\""
    puts "end"
    puts "```"
    
    puts "\nTask completed! Follow the instructions above to complete the setup."
  end
end 