require "rails_helper"

RSpec.describe DemoBuilderService do
  let(:org) { create(:organization) }
  let(:client) { instance_double(Demo::ServerClient) }

  before { allow(Demo::ServerClient).to receive(:for_organization).with(org).and_return(client) }

  def customer_with(attrs)
    ActsAsTenant.with_tenant(org) { create(:customer, **attrs.merge(organization: org)) }
  end

  it "maps a Manufacturing lead to the manufacturing template and passes the company" do
    c = customer_with(company: "Nurikon", industry: "Manufacturing")
    expect(client).to receive(:build).with(hash_including(company: "Nurikon", industry: "manufacturing", ref: c.id))
      .and_return("db" => "lead", "url" => "u", "login" => "admin", "password" => "p")
    DemoBuilderService.call(c)
  end

  it "maps Retail/Ecommerce to the retail template" do
    c = customer_with(company: "Zubaidas", industry: "Retail/Ecommerce")
    expect(client).to receive(:build).with(hash_including(industry: "retail")).and_return({})
    DemoBuilderService.call(c)
  end

  it "defaults unknown/blank industries to services and uses the name when company is blank" do
    c = customer_with(company: nil, name: "Faraz", industry: nil)
    expect(client).to receive(:build).with(hash_including(company: "Faraz", industry: "services")).and_return({})
    DemoBuilderService.call(c)
  end
end
