#!/usr/bin/env ruby

# Production script to add WhatsApp chat IDs to customers
# Usage: RAILS_ENV=production ruby add_whatsapp_chat_ids_production.rb

# Load Rails environment
require_relative 'config/environment'

puts "Starting WhatsApp chat ID synchronization for production..."
puts "Environment: #{Rails.env}"
puts "Time: #{Time.current}"
puts "-" * 50

# Find customers with phone numbers but no WhatsApp chat ID
customers_to_update = Customer.where.not(phone: [nil, '']).where(whatsapp_chat_id: [nil, ''])

total_to_update = customers_to_update.count
updated_count = 0
failed_count = 0

puts "Found #{total_to_update} customers with phone numbers but no WhatsApp chat ID"
puts

if total_to_update == 0
  puts "No customers need updating. Script completed."
  exit 0
end

# Process each customer
customers_to_update.find_each.with_index do |customer, index|
  begin
    if customer.phone.present?
      # Extract the phone number without the + sign
      phone_without_plus = customer.phone.gsub(/\A\+/, '')
      
      # Create WhatsApp chat ID in the required format
      whatsapp_chat_id = "#{phone_without_plus}@c.us"
      
      # Update the customer record
      customer.update!(whatsapp_chat_id: whatsapp_chat_id)
      
      # Log the update
      puts "[#{index + 1}/#{total_to_update}] Updated customer #{customer.id} (#{customer.name}): #{customer.phone} -> #{whatsapp_chat_id}"
      updated_count += 1
    end
  rescue => e
    puts "[#{index + 1}/#{total_to_update}] FAILED to update customer #{customer.id} (#{customer.name}): #{e.message}"
    failed_count += 1
  end
  
  # Show progress every 100 records
  if (index + 1) % 100 == 0
    puts "Progress: #{index + 1}/#{total_to_update} processed (#{updated_count} updated, #{failed_count} failed)"
  end
end

# Output final summary
puts
puts "=" * 50
puts "FINAL SUMMARY"
puts "=" * 50
puts "Total customers needing update: #{total_to_update}"
puts "Successfully updated: #{updated_count}"
puts "Failed: #{failed_count}"
puts "Completed at: #{Time.current}"

if failed_count > 0
  puts
  puts "WARNING: #{failed_count} customers failed to update. Check the error messages above."
  exit 1
else
  puts
  puts "SUCCESS: All customers updated successfully!"
  exit 0
end