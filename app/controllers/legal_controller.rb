# Public legal pages on the root domain (no tenant, no login). Required for the
# Meta App going Live: a valid Privacy Policy URL, Terms of Service, and
# user-data deletion instructions.
class LegalController < ApplicationController
  layout "legal"

  def privacy; end
  def terms; end
  def data_deletion; end
end
