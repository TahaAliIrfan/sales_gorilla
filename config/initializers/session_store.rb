# Use an explicit, app-specific session cookie key.
#
# The "revamp" app at ascolto.tecaudex.com sets a session cookie scoped to
# `domain=tecaudex.com`, which the browser also sends to crm.tecaudex.com. When
# both apps used the same default key (`_tecaudex_crm_session`), the two cookies
# collided on crm and Rails read the wrong one — wiping `omniauth.state` and
# making Google sign-in fail with `csrf_detected`. A distinct key keeps crm's
# session isolated regardless of what other *.tecaudex.com apps set.
Rails.application.config.session_store :cookie_store, key: "_tecaudex_crm_app_session"
