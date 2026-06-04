# Relay Inbox — cross-lead conversation triage. Ports
# docs/design/relay-app/project/app/view-inbox.jsx: a 360px conversation list
# (every lead that has a WhatsApp thread, with unread count + last-message
# snippet) beside the selected lead's full conversation canvas + composer,
# reusing the lead workspace's Relay::ConversationBuilder and partials.
#
# The list is bounded (LIST_LIMIT) and built from two queries — a grouped
# aggregate for ordering/unread counts and a single DISTINCT ON fetch for the
# snippet rows — so it never N+1s regardless of thread count. All WhatsApp
# reads are auto-scoped to the org by acts_as_tenant; customer visibility is
# enforced with Pundit's policy_scope so associates only see their own leads.
class InboxController < TenantController
  layout "relay"
  before_action :require_login
  after_action :verify_policy_scoped, only: :index

  LIST_LIMIT = 50

  # GET /inbox(/:customer_id)?filter=all|unread&q=
  def index
    @filter = %w[all unread].include?(params[:filter]) ? params[:filter] : "all"
    @query  = params[:q].to_s.strip

    visible_customer_ids = policy_scope(Customer).select(:id)
    @conversations = build_conversations(visible_customer_ids)

    @selected = select_customer(visible_customer_ids)
    return unless @selected

    @conversation = Relay::ConversationBuilder.new(@selected).events
  end

  private

  # Aggregates the visible leads' WhatsApp threads into list rows. One grouped
  # query orders by latest activity and counts unread inbound messages; a second
  # DISTINCT ON query pulls the latest message per customer for the snippet.
  # Both are bounded to LIST_LIMIT customers.
  def build_conversations(visible_customer_ids)
    grouped = WhatsappMessage
              .where(customer_id: visible_customer_ids)
              .group(:customer_id)
              .select(
                :customer_id,
                Arel.sql("MAX(COALESCE(timestamp, created_at)) AS last_at"),
                Arel.sql("COUNT(*) FILTER (WHERE direction = 'inbound' AND read = FALSE) AS unread_count")
              )
    grouped = grouped.having(Arel.sql("COUNT(*) FILTER (WHERE direction = 'inbound' AND read = FALSE) > 0")) if @filter == "unread"
    grouped = grouped.order(Arel.sql("last_at DESC")).limit(LIST_LIMIT).to_a

    return [] if grouped.empty?

    customer_ids = grouped.map(&:customer_id)
    customers_by_id = filtered_customers(customer_ids).index_by(&:id)
    snippets_by_id  = latest_messages(customer_ids)

    grouped.filter_map do |row|
      customer = customers_by_id[row.customer_id]
      next unless customer # dropped by name search

      msg = snippets_by_id[row.customer_id]
      {
        customer: customer,
        unread:   row.unread_count.to_i,
        last_at:  row.last_at,
        snippet:  snippet_for(msg)
      }
    end
  end

  # Loads the list's customers, optionally narrowed by the name search. Kept as
  # one query (the search runs in SQL, not Ruby).
  def filtered_customers(customer_ids)
    scope = policy_scope(Customer).where(id: customer_ids)
    if @query.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope = scope.where("customers.name ILIKE :q OR customers.company ILIKE :q", q: like)
    end
    scope.to_a
  end

  # Latest WhatsApp message per customer in a single DISTINCT ON query.
  def latest_messages(customer_ids)
    WhatsappMessage
      .where(customer_id: customer_ids)
      .select("DISTINCT ON (customer_id) *")
      .order(Arel.sql("customer_id, COALESCE(timestamp, created_at) DESC"))
      .index_by(&:customer_id)
  end

  # "You: …" prefix for outbound, plain body for inbound; media-only messages
  # already carry a "[n media attachment(s)]" body from the sync path.
  def snippet_for(message)
    return "No messages yet" if message.nil?
    text = message.body.to_s.strip
    text = "[attachment]" if text.blank?
    message.direction == "outbound" ? "You: #{text}" : text
  end

  # The lead shown in the right pane: the :customer_id param when given and
  # visible, otherwise the first conversation in the list.
  def select_customer(visible_customer_ids)
    if params[:customer_id].present?
      return policy_scope(Customer).where(id: visible_customer_ids).find_by(id: params[:customer_id])
    end
    @conversations.first&.dig(:customer)
  end
end
