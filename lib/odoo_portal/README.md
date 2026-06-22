# Odoo Portal Node Agent
Stateless Puppeteer CLI driven by `OdooPortal::BrowserRunner` (Ruby).
Contract: JSON on stdin -> JSON on stdout. Actions: validate_session,
list_leads, show_lead, write_action. Selectors are passed in from Ruby and
captured against the live portal during implementation.
