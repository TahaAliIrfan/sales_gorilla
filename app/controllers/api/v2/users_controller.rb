class Api::V2::UsersController < Api::V2::BaseController
  before_action :set_user, only: [:show, :update, :destroy]
  after_action :verify_authorized, except: [:index]
  after_action :verify_policy_scoped, only: [:index]

  def index
    @users = policy_scope(User)
    
    # Apply filters  
    if params[:role].present?
      role = Role.find_by(key: params[:role])
      @users = @users.joins(:roles).where(roles: { id: role.id }) if role
    end
    @users = @users.where('name ILIKE ? OR email ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    # Sorting
    sort_field = params[:sort] || 'name'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    @users = @users.order("#{sort_field} #{sort_direction}")
    
    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @users = @users.page(page).per(per_page)
    
    render_success({
      users: @users.map do |user|
        user.as_json(only: [:id, :name, :email, :phone, :timezone, :created_at, :updated_at])
            .merge(role: user.highest_role&.key || 'associate')
      end,
      pagination: {
        current_page: @users.current_page,
        total_pages: @users.total_pages,
        total_count: @users.total_count,
        per_page: @users.limit_value
      }
    })
  end

  def show
    authorize @user
    render_success({
      user: @user.as_json(only: [:id, :name, :email, :phone, :timezone, :fcm_token, :created_at, :updated_at])
                  .merge(role: @user.highest_role&.key || 'associate')
    })
  end

  def create
    @user = User.new(user_params)
    authorize @user
    
    if @user.save
      render_success(
        { 
          user: @user.as_json(
            only: [:id, :name, :email, :role, :phone, :timezone, :created_at, :updated_at]
          )
        }, 
        'User created successfully', 
        :created
      )
    else
      render_error('Failed to create user', @user.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    authorize @user
    
    if @user.update(user_params)
      render_success(
        { 
          user: @user.as_json(
            only: [:id, :name, :email, :role, :phone, :timezone, :created_at, :updated_at]
          )
        }, 
        'User updated successfully'
      )
    else
      render_error('Failed to update user', @user.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    authorize @user
    
    if @user.destroy
      render_success(nil, 'User deleted successfully')
    else
      render_error('Failed to delete user')
    end
  end

  def update_fcm_token
    authorize @current_user
    
    fcm_token = params[:fcm_token]
    
    if fcm_token.blank?
      render_error('FCM token is required', ['FCM token cannot be blank'], :unprocessable_entity)
      return
    end
    
    if @current_user.update(fcm_token: fcm_token)
      render_success(
        { 
          user: @current_user.as_json(only: [:id, :name, :email, :fcm_token, :updated_at]),
          fcm_token_updated: true
        }, 
        'FCM token updated successfully'
      )
    else
      render_error('Failed to update FCM token', @current_user.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :phone, :timezone)
  end
end