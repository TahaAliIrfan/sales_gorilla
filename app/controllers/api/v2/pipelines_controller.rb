class Api::V2::PipelinesController < Api::V2::BaseController
  before_action :require_authentication

  def index
    render_success(pipelines: current_user.assigned_pipelines.as_json)
  end

  private

  def require_authentication
    render_error('Authentication required', [], :unauthorized) unless current_user
  end
end