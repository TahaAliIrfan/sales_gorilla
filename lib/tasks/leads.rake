namespace :leads do
  desc "Backfill rule-based lead scores for all existing customers (no AI calls)"
  task backfill_scores: :environment do
    total = Customer.count
    done = 0
    failed = 0
    puts "Backfilling rule-based lead scores for #{total} customers (no AI)…"

    Customer.find_each(batch_size: 200) do |customer|
      begin
        LeadScoringService.new(customer).refresh!(run_ai: false)
      rescue => e
        failed += 1
        Rails.logger.error("leads:backfill_scores failed for customer #{customer.id}: #{e.message}")
      end
      done += 1
      puts "  scored #{done}/#{total}" if (done % 500).zero?
    end

    puts "Done. #{done}/#{total} customers scored (rules only), #{failed} failed."
  end
end
