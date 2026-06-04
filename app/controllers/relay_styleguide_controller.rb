# app/controllers/relay_styleguide_controller.rb
#
# Development-only gallery proving the Relay foundation: layout, shell,
# tokens, and Stimulus primitives. Not routed outside development.
class RelayStyleguideController < TenantController
  layout "relay"

  def index
    flash.now[:notice] = "Foundation loaded — this is a toast." if params[:toast]
  end
end
