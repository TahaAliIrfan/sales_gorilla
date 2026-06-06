namespace :pundit do
  desc "Generate a Pundit policy for a given model"
  task :generate_policy, [:model_name] => :environment do |t, args|
    model_name = args[:model_name]
    
    if model_name.blank?
      puts "Usage: rails pundit:generate_policy[ModelName]"
      exit
    end
    
    model_name = model_name.classify
    policy_name = "#{model_name}Policy"
    
    # Check if the model exists
    begin
      model_class = model_name.constantize
    rescue NameError
      puts "Error: Model '#{model_name}' not found."
      exit
    end
    
    policy_path = Rails.root.join("app/policies/#{model_name.underscore}_policy.rb")
    
    if File.exist?(policy_path)
      puts "Policy file already exists at #{policy_path}"
      exit
    end
    
    # Create the policy file
    File.open(policy_path, "w") do |file|
      file.puts <<~RUBY
        # frozen_string_literal: true

        class #{policy_name} < ApplicationPolicy
          class Scope < Scope
            def resolve
              if user.admin?
                scope.all
              else
                # Customize this as needed
                scope.where(user_id: user.id)
              end
            end
          end
          
          def index?
            true # All authenticated users can list #{model_name.pluralize}
          end
          
          def show?
            user.admin? || record.user_id == user.id
          end
          
          def create?
            true # All authenticated users can create #{model_name.pluralize}
          end
          
          def update?
            user.admin? || record.user_id == user.id
          end
          
          def destroy?
            user.admin? || record.user_id == user.id
          end
        end
      RUBY
    end
    
    puts "Successfully created policy at #{policy_path}"
  end
  
  desc "List all controllers without Pundit policies"
  task list_missing_policies: :environment do
    # Get all controllers in the app/controllers directory
    controller_files = Dir.glob(Rails.root.join("app/controllers/**/*_controller.rb"))
    controller_names = controller_files.map do |file|
      # Extract the controller name from the file path
      file_name = File.basename(file, ".rb")
      file_name.camelize
    end
    
    # Skip API controllers and non-resource controllers
    skip_controllers = ["ApplicationController", "DashboardController", "HomeController", "SettingsController", "SessionsController"]
    
    # Check for missing policies
    missing_policies = []
    
    controller_names.each do |controller_name|
      next if skip_controllers.include?(controller_name)
      next if controller_name.include?("API::")
      
      # Guess the model name from controller
      model_name = controller_name.gsub("Controller", "").singularize
      policy_class_name = "#{model_name}Policy"
      
      # Check if policy exists
      policy_file = Rails.root.join("app/policies/#{model_name.underscore}_policy.rb")
      
      unless File.exist?(policy_file)
        missing_policies << model_name
      end
    end
    
    if missing_policies.empty?
      puts "All controllers have corresponding Pundit policies."
    else
      puts "Controllers missing Pundit policies:"
      missing_policies.each do |model_name|
        puts "  - #{model_name}"
      end
      
      puts "\nTo generate a policy, run:"
      puts "  rails pundit:generate_policy[ModelName]"
    end
  end
end 