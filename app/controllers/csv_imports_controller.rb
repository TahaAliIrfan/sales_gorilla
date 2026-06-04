require 'cgi'
require 'fileutils'

class CsvImportsController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :authorize_import_access
  
  
  def new
    Rails.logger.info "CSV Import new action accessed by user: #{current_user&.name}"
    @csv_import = {
      step: 'upload'
    }
    
    # Check if we should render without layout for debugging
    if params[:debug] == 'true'
      render layout: false
    end
  end
  
  def upload
    begin
      Rails.logger.info "CSV Upload started with params: #{params.inspect}"
      uploaded_file = params[:csv_file]
      
      Rails.logger.info "Uploaded file: #{uploaded_file.inspect}"
      
      if uploaded_file.blank?
        Rails.logger.warn "No CSV file uploaded"
        flash[:error] = "Please select a CSV file to upload"
        redirect_to new_csv_import_path and return
      end
      
      # Validate file type
      unless uploaded_file.content_type == 'text/csv' || uploaded_file.original_filename.downcase.ends_with?('.csv')
        flash[:error] = "Please upload a valid CSV file"
        redirect_to new_csv_import_path and return
      end
      
      # Parse CSV and detect fields
      csv_service = CsvImportService.new(uploaded_file)
      @parsed_data = csv_service.parse_and_analyze
      
      if @parsed_data[:error]
        flash[:error] = @parsed_data[:error]
        redirect_to new_csv_import_path and return
      end
      
      # Create temporary directory for CSV uploads if it doesn't exist
      temp_dir = Rails.root.join('tmp', 'csv_uploads')
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)
      
      # Save uploaded file to temporary location
      upload_token = SecureRandom.hex(16)
      temp_file_path = temp_dir.join("#{upload_token}.csv")
      
      # Read and save the CSV content
      uploaded_file.rewind
      csv_content = uploaded_file.read.force_encoding('UTF-8')
      File.write(temp_file_path, csv_content)
      
      # Create CSV upload record
      @csv_upload = CsvUpload.create!(
        user: current_user,
        upload_token: upload_token,
        original_filename: uploaded_file.original_filename,
        file_path: temp_file_path.to_s,
        headers: @parsed_data[:headers],
        sample_rows: @parsed_data[:sample_rows].first(5),
        suggested_mappings: @parsed_data[:suggested_mappings],
        total_rows: @parsed_data[:total_rows],
        status: 'uploaded'
      )
      
      # Redirect to mapping step with upload token
      redirect_to mapping_csv_imports_path(token: @csv_upload.upload_token)
      
    rescue => e
      Rails.logger.error "CSV Upload Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = "Error processing CSV file: #{e.message}"
      redirect_to new_csv_import_path
    end
  end
  
  def mapping
    upload_token = params[:token]
    
    if upload_token.blank?
      flash[:error] = "Invalid upload token. Please upload the file again."
      redirect_to new_csv_import_path and return
    end
    
    @csv_upload = CsvUpload.find_by(upload_token: upload_token, user: current_user)
    
    if @csv_upload.blank?
      flash[:error] = "CSV upload not found or expired. Please upload the file again."
      redirect_to new_csv_import_path and return
    end
    
    if @csv_upload.expired?
      @csv_upload.destroy
      flash[:error] = "CSV upload expired. Please upload the file again."
      redirect_to new_csv_import_path and return
    end
    
    unless @csv_upload.file_exists?
      @csv_upload.destroy
      flash[:error] = "CSV file not found. Please upload the file again."
      redirect_to new_csv_import_path and return
    end
    
    @csv_import = {
      step: 'mapping',
      headers: @csv_upload.headers,
      sample_rows: @csv_upload.sample_rows,
      total_rows: @csv_upload.total_rows,
      suggested_mappings: @csv_upload.suggested_mappings,
      upload_token: @csv_upload.upload_token
    }
  end
  
  def import
    begin
      Rails.logger.info "CSV Import action started"
      
      # Handle JSON request (AJAX)
      if request.content_type == 'application/json'
        request_data = JSON.parse(request.raw_post)
        field_mappings = request_data['field_mappings'] || {}
        upload_token = request_data['upload_token']
        default_lead_source = request_data['default_lead_source']
        
        Rails.logger.info "JSON field mappings: #{field_mappings.inspect}"
        Rails.logger.info "Upload token: #{upload_token}"
        Rails.logger.info "Default lead source: #{default_lead_source}"
        
        if upload_token.blank?
          render json: { success: false, error: "Invalid upload token. Please upload the file again." }
          return
        end
        
        csv_upload = CsvUpload.find_by(upload_token: upload_token, user: current_user)
        
        if csv_upload.blank?
          render json: { success: false, error: "CSV upload not found or expired. Please upload the file again." }
          return
        end
        
        if csv_upload.expired?
          csv_upload.destroy
          render json: { success: false, error: "CSV upload expired. Please upload the file again." }
          return
        end
        
        unless csv_upload.file_exists?
          csv_upload.destroy
          render json: { success: false, error: "CSV file not found. Please upload the file again." }
          return
        end
        
        # Update the upload with the selected lead source
        if default_lead_source.present? && csv_upload.respond_to?(:lead_source=)
          csv_upload.update!(lead_source: default_lead_source)
        end
        
        # Start background job for import
        job_id = CsvImportWorker.perform_async(csv_upload.id, field_mappings, current_user.id)
        
        # Mark upload as processing
        csv_upload.update!(status: 'processing')
        
        render json: { 
          success: true, 
          message: "Import started in background",
          job_id: job_id,
          imported_count: "Processing...",
          redirect_url: customers_path
        }
      else
        # Handle form request (fallback - should not be used now)
        render json: { success: false, error: "Only JSON requests supported" }
      end
      
    rescue => e
      Rails.logger.error "CSV Import Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html do
          flash[:error] = "Error importing customers: #{e.message}"
          redirect_to new_csv_import_path
        end
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end
  
  def cancel
    upload_token = params[:token]
    if upload_token.present?
      csv_upload = CsvUpload.find_by(upload_token: upload_token, user: current_user)
      csv_upload&.destroy
    end
    redirect_to customers_path, notice: "CSV import cancelled"
  end
  
  def debug
    Rails.logger.info "Debug action accessed by user: #{current_user&.name}"
    render :debug, layout: false
  end
  
  def simple
    Rails.logger.info "Simple action accessed by user: #{current_user&.name}"
    render :simple, layout: false
  end
  
  private
  
  def authorize_import_access
    # Only admins and managers can import customers
    Rails.logger.info "Checking CSV import authorization for user: #{current_user&.name} (ID: #{current_user&.id})"
    Rails.logger.info "User admin?: #{current_user&.admin?}, manager?: #{current_user&.manager?}"
    
    unless current_user&.admin? || current_user&.manager?
      Rails.logger.warn "User #{current_user&.name} denied access to CSV import - insufficient permissions"
      flash[:error] = "You don't have permission to import customers"
      redirect_to customers_path
    end
  end
  
  def import_params
    # Handle field_mappings parameter safely
    field_mappings = params[:field_mappings]
    
    if field_mappings.is_a?(ActionController::Parameters)
      field_mappings.permit!.to_h
    elsif field_mappings.respond_to?(:to_hash)
      field_mappings.to_hash
    else
      {}
    end
  end
end