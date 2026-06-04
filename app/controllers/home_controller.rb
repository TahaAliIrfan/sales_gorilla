# Public landing on the root domain. No tenant required.
# Signed-in users are nudged to their workspace picker; everyone else sees the
# marketing page with a sign-in CTA.
class HomeController < ApplicationController
  layout "marketing"

  def index
    redirect_to organizations_path if current_user.present?
  end
end
