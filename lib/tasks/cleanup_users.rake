# Remove unauthorized self-service signups from the server.
#
# "Authorized" = email on the company domain (@tecaudex.com) or on the explicit
# allowlist below (kept in sync with Api::V2::AuthenticationController).
#
# Usage:
#   bin/rails users:list_unauthorized                 # dry run — just list them
#   bin/rails users:remove_unauthorized CONFIRM=yes   # delete the safe ones
#   bin/rails users:remove_unauthorized CONFIRM=yes FORCE=yes
#                                                     # also delete ones that own data
#
# By default an unauthorized account that owns business data (customers, deals,
# recordings) is SKIPPED — deleting it could orphan or cascade real records.
# Re-run with FORCE=yes only after reviewing the listed data counts.
namespace :users do
  ALLOWED_DOMAINS = %w[tecaudex.com].freeze
  ALLOWED_EMAILS  = %w[
    ifrah.khurram97@gmail.com
    tahairfan1993@gmail.com
  ].freeze

  def authorized_email?(email)
    e = email.to_s.downcase.strip
    return true if ALLOWED_EMAILS.include?(e)
    ALLOWED_DOMAINS.any? { |d| e.end_with?("@#{d}") }
  end

  # Records that, if present, mean we must not blindly delete the account.
  def data_counts(user)
    {
      customers:   user.customers.count,
      deals:       user.deals.count,
      recordings:  user.recordings.count,
      campaigns:   user.campaigns.count
    }
  end

  def owns_data?(counts)
    counts.values.any?(&:positive?)
  end

  def unauthorized_users
    User.where.not(id: nil).reject { |u| authorized_email?(u.email) }
  end

  desc "List users whose email is not authorized (dry run, no changes)"
  task list_unauthorized: :environment do
    users = unauthorized_users
    if users.empty?
      puts "No unauthorized users found. ✅"
      next
    end

    puts "Found #{users.size} unauthorized user(s):"
    puts "-" * 80
    users.each do |u|
      counts = data_counts(u)
      flag = owns_data?(counts) ? "  ⚠️  OWNS DATA" : ""
      puts format("#%-6d %-40s provider=%-14s created=%s%s",
                  u.id, u.email, (u.provider || "password"),
                  u.created_at&.to_date, flag)
      puts "         #{counts.map { |k, v| "#{k}=#{v}" }.join('  ')}" if owns_data?(counts)
    end
    puts "-" * 80
    puts "Dry run only. To delete: bin/rails users:remove_unauthorized CONFIRM=yes"
  end

  desc "Delete unauthorized users. Requires CONFIRM=yes; FORCE=yes to include data owners."
  task remove_unauthorized: :environment do
    unless ENV["CONFIRM"] == "yes"
      abort "Refusing to delete without CONFIRM=yes. Run users:list_unauthorized first to review."
    end
    force = ENV["FORCE"] == "yes"

    users = unauthorized_users
    if users.empty?
      puts "No unauthorized users found. ✅"
      next
    end

    deleted = 0
    skipped = 0
    failed  = 0

    users.each do |u|
      counts = data_counts(u)
      if owns_data?(counts) && !force
        puts "SKIP  ##{u.id} #{u.email} — owns data (#{counts.map { |k, v| "#{k}=#{v}" }.join(', ')}). Use FORCE=yes to delete."
        skipped += 1
        next
      end

      if u.destroy
        puts "DEL   ##{u.id} #{u.email}"
        deleted += 1
      else
        puts "FAIL  ##{u.id} #{u.email} — #{u.errors.full_messages.join('; ')}"
        failed += 1
      end
    rescue => e
      puts "FAIL  ##{u.id} #{u.email} — #{e.class}: #{e.message}"
      failed += 1
    end

    puts "-" * 80
    puts "Deleted: #{deleted}  Skipped (owns data): #{skipped}  Failed: #{failed}"
  end
end
