class Api::V1::AiCallController < Api::V1::BaseController
  
  WEBHOOK_SECRET = 'wsec_9a8cacffa7ca3da1dc8ca9e0b361e997b96cbe49550e1406a41172ea279a3fa6'
  WEBHOOK_SECRET_DEV= 'wsec_70a7b8e89d20b87317563e7e97ea776a0dd73b7c7fd0c2419ebcb6777884e92f'
  
  def webhook
    # Validate webhook token for official ElevenLabs webhooks
    unless valid_webhook_token?
      render_error('Unauthorized webhook request', nil, :unauthorized)
      return
    end
    
    # Log the received data for debugging
    Rails.logger.info "Eleven Labs AI Call webhook received: #{params.inspect}"
    
    # Process the webhook data
    process_ai_call_data
    
    # Return success response
    render_success(nil, 'Webhook processed successfully')
  rescue StandardError => e
    Rails.logger.error "Error processing AI call webhook: #{e.message}"
    render_error('Failed to process webhook', e.message, :internal_server_error)
  end
  
  # Handle call start events from frontend
  def start
    Rails.logger.info "AI Call start event: #{params.inspect}"
    
    conversation_id = params[:conversation_id]
    customer_id = params[:customer_id]
    user_id = params[:user_id]
    phone_number = params[:phone_number]
    agent_id = params[:agent_id]
    
    # Validate required parameters
    if conversation_id.blank? || customer_id.blank? || phone_number.blank?
      render_error('Missing required parameters', 'conversation_id, customer_id, and phone_number are required', :bad_request)
      return
    end
    
    # Find customer and user
    customer = Customer.find_by(id: customer_id)
    user = User.find_by(id: user_id) if user_id.present?
    
    unless customer
      render_error('Customer not found', "Customer with ID #{customer_id} not found", :not_found)
      return
    end
    
    # Create call record
    call = ElevenLabsCall.create!(
      customer: customer,
      user: user,
      to_number: phone_number,
      call_id: conversation_id,
      status: 'initiated',
      started_at: Time.current,
      response_data: { agent_id: agent_id }.to_json
    )
    
    Rails.logger.info "Created ElevenLabs call record: #{call.id}"
    render_success({ call_id: call.id, conversation_id: conversation_id }, 'Call started successfully')
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create call record: #{e.message}"
    render_error('Failed to create call record', e.message, :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error "Error starting AI call: #{e.message}"
    render_error('Failed to start call', e.message, :internal_server_error)
  end
  
  # Handle call end events from frontend
  def end
    Rails.logger.info "AI Call end event: #{params.inspect}"
    
    conversation_id = params[:conversation_id]
    duration = params[:duration]
    status = params[:status] || 'completed'
    
    if conversation_id.blank?
      render_error('Missing conversation_id', 'conversation_id is required', :bad_request)
      return
    end
    
    # Find call record
    call = ElevenLabsCall.find_by(call_id: conversation_id)
    
    unless call
      render_error('Call not found', "Call with conversation_id #{conversation_id} not found", :not_found)
      return
    end
    
    # Update call record
    update_params = {
      status: status,
      ended_at: Time.current
    }
    
    update_params[:duration] = duration.to_i if duration.present?
    
    call.update!(update_params)
    
    Rails.logger.info "Updated ElevenLabs call record: #{call.id}"
    render_success({ call_id: call.id }, 'Call ended successfully')
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update call record: #{e.message}"
    render_error('Failed to update call record', e.message, :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error "Error ending AI call: #{e.message}"
    render_error('Failed to end call', e.message, :internal_server_error)
  end
  
  # Handle call failure events from frontend
  def fail
    Rails.logger.info "AI Call fail event: #{params.inspect}"
    
    conversation_id = params[:conversation_id]
    error_message = params[:error_message] || 'Unknown error'
    
    if conversation_id.blank?
      render_error('Missing conversation_id', 'conversation_id is required', :bad_request)
      return
    end
    
    # Find call record
    call = ElevenLabsCall.find_by(call_id: conversation_id)
    
    unless call
      render_error('Call not found', "Call with conversation_id #{conversation_id} not found", :not_found)
      return
    end
    
    # Update call record as failed
    call.update!(
      status: 'failed',
      error_message: error_message,
      ended_at: Time.current
    )
    
    Rails.logger.info "Marked ElevenLabs call as failed: #{call.id}"
    render_success({ call_id: call.id }, 'Call failure recorded')
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update call record: #{e.message}"
    render_error('Failed to update call record', e.message, :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error "Error recording call failure: #{e.message}"
    render_error('Failed to record failure', e.message, :internal_server_error)
  end
  
  private
  
  def valid_webhook_token?
    # Check for token in headers (common webhook pattern)
    auth_header = request.headers['Authorization']
    webhook_token = request.headers['X-Webhook-Token']
    
    # Check Authorization header format: "Bearer token"
    if auth_header&.start_with?('Bearer ')
      token = auth_header.split(' ').last
      return token == WEBHOOK_SECRET_DEV
    end
    
    # Check X-Webhook-Token header
    if webhook_token
      return webhook_token == WEBHOOK_SECRET_DEV
    end
    
    # Check token in request body
    params[:token] == WEBHOOK_SECRET_DEV
  end
  
  def process_ai_call_data
    # Extract relevant data from the webhook payload
    conversation_id = params[:conversation_id] || params[:call_id]
    phone_number = params[:call]&.dig(:to_number) || params[:phone_number]
    status = params[:status]
    transcript = params[:transcript]
    duration = params[:call]&.dig(:duration) || params[:duration]
    audio_url = params[:recording_url] || params[:audio_url]
    
    Rails.logger.info "Processing ElevenLabs call: #{conversation_id}, Status: #{status}, Phone: #{phone_number}"
    
    if conversation_id.present?
      # Find or create ElevenLabsCall record
      call_record = find_or_create_call_record(conversation_id, phone_number)
      
      if call_record
        update_call_record(call_record, status, duration, transcript, audio_url)
        Rails.logger.info "Successfully processed ElevenLabs call webhook for record: #{call_record.id}"
        
        # If this is a completion webhook with transcript, also store it
        if status == 'completed' && transcript.present?
          store_transcript(call_record, transcript)
        end
        
        # If this is a completion webhook with audio URL, download it
        if status == 'completed' && audio_url.present?
          download_audio_async(call_record, audio_url)
        end
      else
        Rails.logger.error "Could not find or create call record for conversation: #{conversation_id}"
      end
    else
      Rails.logger.error "No conversation_id provided in ElevenLabs webhook"
    end
  end
  
  def find_or_create_call_record(conversation_id, phone_number)
    # First try to find by conversation_id (call_id in our model)
    call_record = ElevenLabsCall.find_by(call_id: conversation_id)
    
    if call_record
      Rails.logger.info "Found existing call record: #{call_record.id}"
      return call_record
    end
    
    # If not found and we have phone number, try to find customer and create record
    if phone_number.present?
      customer = find_customer_by_phone(phone_number)
      
      if customer
        Rails.logger.info "Creating new call record for customer: #{customer.id}"
        call_record = ElevenLabsCall.create!(
          customer: customer,
          user: nil, # Webhook calls don't have a specific user
          to_number: phone_number,
          status: 'initiated',
          call_id: conversation_id,
          started_at: Time.current
        )
        return call_record
      else
        Rails.logger.warn "No customer found with phone number: #{phone_number}"
      end
    end
    
    nil
  end
  
  def find_customer_by_phone(phone_number)
    # Clean phone number for matching
    clean_number = phone_number.gsub(/[^\d+]/, '')
    
    # Try exact match first
    customer = Customer.where(phone: phone_number).first ||
               Customer.where(phone: clean_number).first
    
    # If no exact match, try partial matching
    if customer.nil?
      # Remove country codes and try matching
      number_digits = clean_number.gsub(/^\+?1?/, '').last(10)
      customer = Customer.where("phone LIKE ?", "%#{number_digits}").first
    end
    
    customer
  end
  
  def update_call_record(call_record, status, duration, transcript, audio_url)
    Rails.logger.info "Updating call record #{call_record.id} with status: #{status}"
    
    # Map ElevenLabs status to our internal status
    internal_status = map_status(status)
    
    update_params = {
      status: internal_status
    }
    
    # Add duration if call ended
    if ['ended', 'completed'].include?(status.to_s.downcase) && duration.present?
      update_params[:duration] = duration.to_i
      update_params[:ended_at] = Time.current
    end
    
    # Add transcript if available
    if transcript.present?
      update_params[:transcription] = transcript.is_a?(String) ? transcript : transcript.to_json
    end
    
    # Update the record
    call_record.update!(update_params)
    
    # Download and attach audio file if URL provided
    if audio_url.present? && !call_record.audio_file.attached?
      download_and_attach_audio(call_record, audio_url)
    end
    
    Rails.logger.info "Successfully updated call record #{call_record.id}"
  end
  
  def map_status(elevenlabs_status)
    case elevenlabs_status.to_s.downcase
    when 'started', 'initiated'
      'initiated'
    when 'in_progress', 'ongoing'
      'in_progress'
    when 'ended', 'completed'
      'completed'
    when 'failed', 'error'
      'failed'
    else
      elevenlabs_status
    end
  end
  
  def download_and_attach_audio(call_record, audio_url)
    begin
      Rails.logger.info "Downloading audio file from: #{audio_url}"
      
      # Use a background job for audio download to avoid timeout
      # For now, we'll do a simple download
      require 'net/http'
      require 'tempfile'
      
      uri = URI(audio_url)
      response = Net::HTTP.get_response(uri)
      
      if response.code.to_i == 200
        # Create a temporary file
        temp_file = Tempfile.new(['elevenlabs_call', '.mp3'])
        temp_file.binmode
        temp_file.write(response.body)
        temp_file.rewind
        
        # Attach to the call record
        call_record.audio_file.attach(
          io: temp_file,
          filename: "call_#{call_record.call_id}.mp3",
          content_type: 'audio/mpeg'
        )
        
        temp_file.close
        temp_file.unlink
        
        Rails.logger.info "Successfully attached audio file to call record #{call_record.id}"
      else
        Rails.logger.error "Failed to download audio file: HTTP #{response.code}"
      end
      
    rescue => e
      Rails.logger.error "Error downloading audio file: #{e.message}"
    end
  end
  
  def store_transcript(call_record, transcript_data)
    begin
      Rails.logger.info "Storing transcript for call #{call_record.id}"
      
      # Handle different transcript formats
      formatted_transcript = if transcript_data.is_a?(String)
        transcript_data
      elsif transcript_data.is_a?(Hash) || transcript_data.is_a?(Array)
        transcript_data.to_json
      else
        transcript_data.to_s
      end
      
      call_record.update!(transcription: formatted_transcript)
      Rails.logger.info "Successfully stored transcript for call #{call_record.id}"
      
    rescue => e
      Rails.logger.error "Error storing transcript for call #{call_record.id}: #{e.message}"
    end
  end
  
  def download_audio_async(call_record, audio_url)
    begin
      Rails.logger.info "Queuing audio download for call #{call_record.id}: #{audio_url}"
      
      # For now, do immediate download. In production, consider using a background job
      download_and_attach_audio(call_record, audio_url)
      
    rescue => e
      Rails.logger.error "Error queuing audio download for call #{call_record.id}: #{e.message}"
    end
  end
end