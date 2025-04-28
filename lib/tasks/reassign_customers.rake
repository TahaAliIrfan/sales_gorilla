namespace :customers do
  desc "Reassign customers that are 5 weeks old with specific statuses to tecaudex@gmail.com user (without associated deals)"
  task reassign_old_customers: :environment do
    # Find the target user to whom we'll reassign customers
    target_user = User.find_by(email: 'tecaudex@gmail.com')
    
    if target_user.nil?
      puts "Error: Target user with email tecaudex@gmail.com not found!"
      exit 1
    end

    # Define the statuses we're looking for
    target_statuses = ['Invalid', 'Contact Not Established', 'Unresponsive', 'Exhausted' ]
    
    # Calculate the date 5 weeks ago
    five_weeks_ago = 4.weeks.ago
    
    # Find customers matching the criteria:
    # - Created at least 5 weeks ago
    # - Have one of the target statuses
    # - Currently assigned to a user (not null)
    # - Have no associated deals
    customers = Customer.left_joins(:deals)
                        .where(status: target_statuses)
                        .where('customers.created_at <= ?', five_weeks_ago)
                        .where.not(user_id: nil)
                        .group('customers.id')
                        .having('COUNT(deals.id) = 0')
    
    total_count = customers.count.length
    puts "Found #{total_count} customers to reassign..."
    
    reassigned_count = 0
    
    # Process each customer
    customers.find_each do |customer|
      previous_user = customer.user
      previous_user_email = previous_user&.email || 'No user'
      
      # Update the customer
      customer.update(user_id: target_user.id)
      
      # Log the change
      puts "Reassigned customer: #{customer.id} - #{customer.name} from #{previous_user_email} to tecaudex@gmail.com"
      reassigned_count += 1
    end
    
    puts "Reassignment complete. #{reassigned_count} out of #{total_count} customers were reassigned."
  end
end 