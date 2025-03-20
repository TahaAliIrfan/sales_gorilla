# db/seeds.rb

require 'csv'

User.create(email: "shahab.khan@tecaudex.com")
User.create(email: "saad.ali@tecaudex.com")
User.create(email: "areej.shamshad@tecaudex.com")
User.create(email: "farrukh.hamayoun@tecaudex.com")

# Define user IDs based on the email
users = {
  "Shahab" => User.find_by(email: "shahab.khan@tecaudex.com").id,
  "Saad Ali" => User.find_by(email: "saad.ali@tecaudex.com").id,
  "Areej" => User.find_by(email: "areej.shamshad@tecaudex.com").id,
  "Farrukh" => User.find_by(email: "farrukh.hamayoun@tecaudex.com").id
}

# Path to the CSV file
csv_file_path = Rails.root.join('db', 'CCR_Migration_01.csv')

# Initialize an empty array to store customer data
customers_data = []

# Read the CSV file
CSV.foreach(csv_file_path, headers: true) do |row|
  default_date = Date.strptime(row['created_at'], '%d-%m-%Y')

  # Map CSV columns to customer attributes
  customer_data = {
    name: row['name'],
    email: row['email'],
    phone: row['phone'],
    address: nil, # Address is not provided in the CSV
    company: row['Description'],
    notes: row['notes'],
    user_id: users[row['user_id']] || nil, # Assign user_id based on the assigned user or nil if unassigned
    lead_source: "", # Not provided in the CSV
    country_code: row['country'], # Assuming country_code is the same as country
    linkedin_url: nil, # Not provided in the CSV
    ccr_link: row['ccr_link'],
    project_estimated_cost: nil, # Not provided in the CSV
    project_type: "Not Applicable", # Not provided in the CSV
    idea_description: nil, # Not provided in the CSV
    status: row['Status'],
    call_status: row['call_status'],
    email_status: row['email_status'],
    whatsapp_status: row['whatsapp_status'],
    linkedin_status: "Pending", # Not provided in the CSV
    upwork_profile: "Not Applicable", # Not provided in the CSV
    exhaust_status: "Not Applicable", # Not provided in the CSV
    exhaust_date: nil, # Not provided in the CSV
    country: row['country'],
    preferred_calling_time: "", # Not provided in the CSV
    timezone: row['Timezone'],
    project_scope: "Not Applicable", # Not provided in the CSV
    created_at: default_date # Use the parsed date or default date
  }

  # Add the customer data to the array
  customers_data << customer_data
end

# Create customers
customers_data.each do |customer_data|
  puts "Seeding customer #{customer_data[:email]}."
  customer = Customer.create!(customer_data)
  puts "Seeded customer #{customer.email}."
end

puts "Seeded #{customers_data.size} customers."