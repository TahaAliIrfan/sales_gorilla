# Generates a warm, natural cold-call script (Roman Urdu) for a lead, using the
# enrichment intel + the org's AI. Returns the script text.
class CallScriptService
  def self.call(customer) = new(customer).call

  def initialize(customer)
    @customer = customer
  end

  def call
    Ai::Client.for_organization(@customer.organization).complete(system: system_prompt, prompt: user_prompt)
  end

  private

  def system_prompt
    <<~SYS
      You are a sales coach for Tecaudex, an official Odoo partner in Pakistan.
      Write a warm, natural phone-call script in Roman Urdu (keep English business
      terms like Odoo, POS, inventory, demo where a Pakistani would naturally use
      them). Use the proven 5-step framework: (1) opening, (2) reason for the call,
      (3) 2-3 discovery questions, (4) value tailored to their business, (5) a close
      that books a short live Odoo demo. Do NOT use em dashes. Output ONLY the script.
    SYS
  end

  def user_prompt
    <<~USR
      Write the call script for this lead. The goal is to understand their business
      and book a short live Odoo demo.

      Name: #{@customer.name}
      Company: #{@customer.company}
      Industry: #{@customer.industry}
      What we know about them: #{@customer.enrichment_summary}
    USR
  end
end
