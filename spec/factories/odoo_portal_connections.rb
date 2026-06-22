FactoryBot.define do
  factory :odoo_portal_connection do
    organization
    base_url { "https://www.odoo.com" }
    status { "active" }
    session_cookies { [{ "name" => "session_id", "value" => "abc", "domain" => ".odoo.com" }].to_json }
  end
end
