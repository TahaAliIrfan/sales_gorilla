# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create default deal stages
if DealStage.count == 0
  puts "Creating default deal stages..."
  
  stages = [
    { name: "Qualification", position: 1, description: "Initial contact with the prospect to determine if they are a good fit." },
    { name: "Meeting Scheduled", position: 2, description: "A meeting has been scheduled with the prospect." },
    { name: "Proposal Sent", position: 3, description: "A proposal has been sent to the prospect." },
    { name: "Negotiation", position: 4, description: "Negotiating terms with the prospect." },
    { name: "Closing", position: 5, description: "Final steps before closing the deal." }
  ]
  
  stages.each do |stage|
    DealStage.create!(stage)
  end
  
  puts "Created #{DealStage.count} deal stages."
end

# Make the first user an admin if there are any users
if User.any? && !User.where(is_admin: true).exists?
  puts "Making the first user an admin..."
  User.first.update(is_admin: true)
  puts "User #{User.first.name} is now an admin."
end
