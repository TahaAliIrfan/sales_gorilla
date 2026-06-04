# Admin-only editor for the per-org taxonomy lists (lead sources, customer
# statuses, call/email/whatsapp/linkedin statuses, exhaust statuses, project
# types). Backed by app/models/taxonomy.rb; rename/delete cascade via
# TaxonomyManagementService.
class Settings::TaxonomiesController < TenantController
  before_action :require_login
  before_action :load_taxonomy, only: %i[update destroy]
  before_action :validate_kind, only: %i[index create reorder]

  def index
    authorize Taxonomy
    @kind = params[:kind].presence_in(Taxonomy::KINDS) || "lead_source"
    @taxonomies_by_kind = Taxonomy::KINDS.index_with do |k|
      current_organization.taxonomies.where(kind: k).order(:position, :id)
    end
    @current_list = @taxonomies_by_kind[@kind]
  end

  def create
    authorize Taxonomy

    @taxonomy = current_organization.taxonomies.build(create_params)
    @taxonomy.kind = params[:kind]

    if @taxonomy.save
      respond_to do |format|
        format.html { redirect_to settings_taxonomies_path(kind: @taxonomy.kind), notice: "Added '#{@taxonomy.name}'." }
        format.json { render json: { id: @taxonomy.id, name: @taxonomy.name }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to settings_taxonomies_path(kind: @taxonomy.kind), alert: @taxonomy.errors.full_messages.to_sentence }
        format.json { render json: { errors: @taxonomy.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    authorize @taxonomy

    new_name = params.dig(:taxonomy, :name).to_s.strip
    if new_name.blank?
      return redirect_to settings_taxonomies_path(kind: @taxonomy.kind), alert: "Name can't be blank."
    end

    begin
      TaxonomyManagementService.new(@taxonomy).rename!(to: new_name)
      redirect_to settings_taxonomies_path(kind: @taxonomy.kind),
                  notice: "Renamed to '#{new_name}'. References cascaded."
    rescue TaxonomyManagementService::InvalidReassignment, ActiveRecord::RecordInvalid => e
      redirect_to settings_taxonomies_path(kind: @taxonomy.kind), alert: e.message
    end
  end

  def destroy
    authorize @taxonomy

    reassign_to = params[:reassign_to].to_s.strip.presence

    begin
      service = TaxonomyManagementService.new(@taxonomy)
      reassigned = service.customer_usage_count
      service.destroy!(reassign_to: reassign_to)

      notice = if reassigned.zero?
                 "Removed '#{@taxonomy.name}'."
               elsif reassign_to
                 "Removed '#{@taxonomy.name}' and reassigned #{reassigned} #{"customer".pluralize(reassigned)} to '#{reassign_to}'."
               else
                 "Removed '#{@taxonomy.name}' and cleared the value on #{reassigned} #{"customer".pluralize(reassigned)}."
               end

      redirect_to settings_taxonomies_path(kind: @taxonomy.kind), notice: notice
    rescue TaxonomyManagementService::InvalidReassignment => e
      redirect_to settings_taxonomies_path(kind: @taxonomy.kind), alert: e.message
    end
  end

  # POST /settings/taxonomies/reorder?kind=lead_source
  # Body: ids[] = ordered taxonomy IDs (from the drag-sort UI).
  def reorder
    authorize Taxonomy, :reorder?

    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    rows = current_organization.taxonomies.where(kind: params[:kind], id: ids).index_by(&:id)

    Taxonomy.transaction do
      ids.each_with_index do |id, idx|
        rows[id]&.update_column(:position, idx + 1)
      end
    end

    head :no_content
  end

  # Lightweight JSON endpoint used by the delete-confirmation modal to show
  # the usage count + the sibling values an admin can reassign to.
  def usage
    authorize Taxonomy, :destroy?

    @taxonomy = current_organization.taxonomies.find(params[:id])
    service = TaxonomyManagementService.new(@taxonomy)
    siblings = current_organization.taxonomies
                                   .where(kind: @taxonomy.kind, archived: false)
                                   .where.not(id: @taxonomy.id)
                                   .order(:position, :id)
                                   .pluck(:name)

    render json: {
      id: @taxonomy.id,
      name: @taxonomy.name,
      kind: @taxonomy.kind,
      count: service.customer_usage_count,
      siblings: siblings
    }
  end

  private

  def load_taxonomy
    @taxonomy = current_organization.taxonomies.find(params[:id])
  end

  def validate_kind
    return if params[:kind].blank? || Taxonomy::KINDS.include?(params[:kind])

    redirect_to settings_taxonomies_path, alert: "Unknown taxonomy kind."
  end

  def create_params
    params.require(:taxonomy).permit(:name)
  end
end
