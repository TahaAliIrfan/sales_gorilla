module OdooPortal
  # Translates a CRM Customer state into a portal write-back action. Kept tiny
  # and declarative; later this becomes per-org configurable (mirrors the Meta
  # status->event mapping).
  class EventMap
    MAP = {
      "Not Interested"      => { kind: "exception", note: "Marked Not Interested in CRM" },
      "Invalid"             => { kind: "exception", note: "Marked Invalid in CRM" },
      "Contact Established" => { kind: "note", note: "Contact established (CRM)" },
      "Converted"           => { kind: "note", note: "Converted (CRM)" }
    }.freeze

    def self.action_for(customer)
      MAP[customer.status]&.dup
    end
  end
end
