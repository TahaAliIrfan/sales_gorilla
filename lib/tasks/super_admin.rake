namespace :super_admin do
  desc "Grant platform super-admin to a user by email: rake super_admin:grant[email@example.com]"
  task :grant, [ :email ] => :environment do |_t, args|
    user = User.find_by("lower(email) = ?", args[:email].to_s.downcase.strip)
    abort "No user found with email #{args[:email].inspect}" unless user
    user.update!(super_admin: true)
    puts "Granted super_admin to #{user.email} (id=#{user.id})."
  end

  desc "Revoke platform super-admin from a user by email: rake super_admin:revoke[email@example.com]"
  task :revoke, [ :email ] => :environment do |_t, args|
    user = User.find_by("lower(email) = ?", args[:email].to_s.downcase.strip)
    abort "No user found with email #{args[:email].inspect}" unless user
    user.update!(super_admin: false)
    puts "Revoked super_admin from #{user.email} (id=#{user.id})."
  end

  desc "List all platform super-admins"
  task list: :environment do
    admins = User.where(super_admin: true).order(:email)
    if admins.any?
      admins.each { |u| puts "#{u.email} (id=#{u.id})" }
    else
      puts "No super admins."
    end
  end
end
