# Share the session cookie across the root domain and every tenant subdomain
# so signing in on tecaudex.com is recognized on acme.tecaudex.com.
# `domain: :all` automatically derives the eTLD+1 (e.g. `.tecaudex.com`).
Rails.application.config.session_store :cookie_store,
                                       key: "_tecaudex_crm_session",
                                       domain: :all,
                                       tld_length: 2
