# Researches a lead via the org's AI (with web search) and returns structured
# intel: a plain summary, an industry bucket, a 0-100 legitimacy score, and a
# junk flag. Pure-ish: one AI call in, a parsed Hash out (no DB writes here).
class LeadEnrichmentService
  INDUSTRIES = ["Manufacturing", "Retail/Ecommerce", "Services", "Real Estate",
                "Healthcare", "Technology", "Other"].freeze

  def self.call(customer) = new(customer).call

  def initialize(customer)
    @customer = customer
  end

  def call
    raw = Ai::Client.for_organization(@customer.organization).research(prompt: prompt)
    parse(raw)
  end

  private

  def prompt
    <<~PROMPT
      Research this sales lead using web search and assess it.

      Name: #{@customer.name}
      Company: #{@customer.company}
      Email: #{@customer.email}
      Phone: #{@customer.phone}
      Country: #{@customer.country_code}
      Notes: #{@customer.idea_description}

      Return ONLY a JSON object (no prose around it) with keys:
        "summary": 2-3 sentence plain summary of what the business is and does,
        "industry": one of #{INDUSTRIES.inspect},
        "legitimacy_score": integer 0-100 (how real/serious this lead looks),
        "is_junk": boolean (true if it looks fake/placeholder/no real business).
    PROMPT
  end

  def parse(raw)
    json = raw.to_s[/\{.*\}/m]
    unless json
      return { summary: raw.to_s.strip.truncate(500).presence, industry: nil, legitimacy_score: nil, is_junk: nil }
    end
    data = JSON.parse(json)
    {
      summary: data["summary"].presence,
      industry: data["industry"].presence,
      legitimacy_score: data["legitimacy_score"] && data["legitimacy_score"].to_i,
      is_junk: [true, "true"].include?(data["is_junk"])
    }
  rescue JSON::ParserError
    { summary: raw.to_s.strip.truncate(500).presence, industry: nil, legitimacy_score: nil, is_junk: nil }
  end
end
