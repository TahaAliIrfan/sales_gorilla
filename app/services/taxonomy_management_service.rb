# Handles the side effects of renaming or deleting a Taxonomy row. Customer
# columns store the value as a string, and several OrganizationFeature settings
# reference taxonomy values by name — both need to be kept in sync.
#
# Usage:
#   TaxonomyManagementService.new(taxonomy).rename!(to: "New Name")
#   TaxonomyManagementService.new(taxonomy).destroy!(reassign_to: "Other Source")
#
# All cascades run inside a transaction; raises if anything goes wrong.
class TaxonomyManagementService
  class InvalidReassignment < StandardError; end

  attr_reader :taxonomy

  def initialize(taxonomy)
    @taxonomy = taxonomy
  end

  # Rename the taxonomy value and cascade to every place that references it
  # by string: Customer.<column> rows, and the Meta feature's hash settings
  # (eligible_sources, customer_status_mappings, source_action_sources).
  def rename!(to:)
    new_name = to.to_s.strip
    raise InvalidReassignment, "New name can't be blank" if new_name.blank?
    return taxonomy if new_name == taxonomy.name

    Taxonomy.transaction do
      old_name = taxonomy.name
      taxonomy.update!(name: new_name)
      apply_to_customers(old_name, new_name)
      apply_to_meta_settings(old_name, new_name)
    end
    taxonomy
  end

  # Reassign every customer using this taxonomy value to a different value,
  # then destroy the taxonomy row. Pass nil/blank `reassign_to` to clear the
  # column (set to NULL) instead of reassigning.
  def destroy!(reassign_to: nil)
    target = reassign_to.to_s.strip.presence
    if target && !sibling_names.include?(target)
      raise InvalidReassignment, "'#{target}' is not a value for #{taxonomy.kind}"
    end

    Taxonomy.transaction do
      apply_to_customers(taxonomy.name, target)
      apply_to_meta_settings(taxonomy.name, target)
      taxonomy.destroy!
    end
  end

  # Count of Customer rows currently using this value. Used by the delete
  # modal to show "You're about to reassign N customers."
  def customer_usage_count
    column = Taxonomy::CUSTOMER_COLUMN[taxonomy.kind]
    return 0 unless column

    Customer.where(organization_id: taxonomy.organization_id, column => taxonomy.name).count
  end

  private

  def sibling_names
    Taxonomy.where(organization_id: taxonomy.organization_id, kind: taxonomy.kind)
            .where.not(id: taxonomy.id)
            .pluck(:name)
  end

  def apply_to_customers(from, to)
    column = Taxonomy::CUSTOMER_COLUMN[taxonomy.kind]
    return unless column

    scope = Customer.where(organization_id: taxonomy.organization_id, column => from)
    scope.update_all(column => to)
  end

  # Meta's feature_card stores taxonomy values by name in three places:
  #   - eligible_sources (array of lead_source names)
  #   - customer_status_mappings (hash keyed by status name)
  #   - source_action_sources (hash keyed by lead_source name)
  # When admin renames or deletes a value, those references go stale unless
  # we sweep them too.
  def apply_to_meta_settings(from, to)
    feature = taxonomy.organization.feature(:meta_conversions)
    return unless feature

    settings = feature.settings_hash.dup

    case taxonomy.kind
    when "lead_source"
      settings["eligible_sources"] = transform_array(settings["eligible_sources"], from, to)
      settings["source_action_sources"] = transform_hash_keys(settings["source_action_sources"], from, to)
    when "customer_status"
      settings["customer_status_mappings"] = transform_hash_keys(settings["customer_status_mappings"], from, to)
    end

    feature.update!(settings: settings)
  end

  def transform_array(arr, from, to)
    return arr unless arr.is_a?(Array)
    if to
      arr.map { |v| v == from ? to : v }.uniq
    else
      arr.reject { |v| v == from }
    end
  end

  def transform_hash_keys(hash, from, to)
    return hash unless hash.is_a?(Hash)
    return hash unless hash.key?(from)

    value = hash.delete(from)
    hash[to] = value if to
    hash
  end
end
