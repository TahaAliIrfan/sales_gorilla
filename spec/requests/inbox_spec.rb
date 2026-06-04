require "rails_helper"

# Phase 6 Inbox smoke + scoping coverage. Drives the real controller + view
# through a tenant subdomain request, so the conversation list, unread badges,
# and the reused lead conversation canvas all render end-to-end.
RSpec.describe "Relay Inbox", type: :request do
  let(:org)   { create(:organization, subdomain: "inbox-test") }
  let(:admin) { create(:user) }
  let(:host)  { "#{org.subdomain}.example.com" }

  before do
    ActsAsTenant.with_tenant(org) do
      create(:membership, :admin, user: admin, organization: org)
      admin.assign_role(:admin)
    end
    # Web session auth has no login route in tests; stub the session lookup.
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
    host! host
  end

  def with_messages
    ActsAsTenant.with_tenant(org) do
      customer = create(:customer, name: "Ada Lovelace", organization: org, user: admin)
      customer.whatsapp_messages.create!(message_id: "in-1", direction: "inbound",
        body: "Hi, is the unit still available?", read: false, timestamp: 2.hours.ago)
      customer.whatsapp_messages.create!(message_id: "out-1", direction: "outbound",
        body: "Yes it is!", status: "sent", timestamp: 1.hour.ago)
      customer
    end
  end

  it "renders the inbox list with a conversation and the reused canvas for an admin" do
    customer = with_messages
    get inbox_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ada Lovelace")          # list row + header
    expect(response.body).to include("rl-convo")              # conversation list rows
    expect(response.body).to include("composer__tabs")        # reused composer
    expect(response.body).to include("Yes it is!")            # latest-message snippet (You: …)
    expect(response.body).not_to include("ic--missing")       # all icons vendored
  end

  it "shows an empty state when there are no conversations" do
    get inbox_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Inbox zero")
  end

  it "renders the selected conversation when a customer_id is given" do
    customer = with_messages
    get inbox_path(customer.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Continuous conversation")
  end

  it "filters to unread only" do
    customer = with_messages
    ActsAsTenant.with_tenant(org) do
      customer.whatsapp_messages.where(direction: "inbound").update_all(read: true)
    end
    get inbox_path(filter: "unread")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No unread conversations")
  end
end
