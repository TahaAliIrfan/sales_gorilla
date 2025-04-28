require 'google/apis/gmail_v1'
require 'base64'
require 'mail'

class GmailService
  attr_reader :gmail, :user
  
  def initialize(user)
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.client_options.application_name = 'Tecaudex CRM'
    @gmail.authorization = auth_client
  end
  
  # Fetch emails for a specific customer
  def fetch_emails_for_customer(customer, max_results = 100)
    return [] unless customer.email.present?
    
    # Search for emails to or from the customer
    query = "(to:#{customer.email} OR from:#{customer.email})"
    begin
      messages = gmail.list_user_messages('me', q: query, max_results: max_results)
      return [] unless messages&.messages
      
      processed_emails = []
      
      messages.messages.each do |message_data|
        begin
          # Get the full message
          message = gmail.get_user_message('me', message_data.id)
          
          # Process the message and add to results if successful
          if email = process_message(message, customer)
            processed_emails << email
          end
        rescue Google::Apis::ClientError => e
          Rails.logger.error("Error processing message ID #{message_data.id}: #{e.message}")
          next # Skip this message and continue with the next one
        rescue StandardError => e
          Rails.logger.error("Unexpected error processing message ID #{message_data.id}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          next # Skip this message and continue with the next one
        end
      end
      
      processed_emails
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error("Authorization error: #{e.message}")
      refresh_token
      retry
    rescue Google::Apis::ServerError => e
      Rails.logger.error("Google API server error: #{e.message}")
      [] # Return empty array on server errors
    rescue Google::Apis::ClientError => e
      Rails.logger.error("Google API client error: #{e.message}")
      [] # Return empty array on client errors
    rescue => e
      Rails.logger.error("Error fetching emails: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      [] # Return empty array on other errors
    end
  end
  
  # Send an email to a customer
  def send_email(customer, subject, body_html, body_text = nil, attachments = [])
    return false unless customer.email.present?
    
    begin
      # Create a Mail message
      mail = Mail.new
      mail.from = "#{user.name} <#{user.email}>"
      mail.to = customer.email
      mail.subject = subject
      
      # Set up multipart email
      mail.text_part = Mail::Part.new do
        body body_text
      end
      
      mail.html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body body_html
      end
      
      # Add attachments if any
      attachments.each do |attachment|
        mail.add_file(
          filename: attachment[:filename],
          content: File.read(attachment[:path])
        )
      end

      result = gmail.send_user_message('me', upload_source: StringIO.new(mail.to_s), content_type: 'message/rfc822')
      
      if result
        # Create an Email record in the database
        email = Email.create!(
          customer: customer,
          user: user,
          message_id: result.id,
          gmail_thread_id: result.thread_id,
          subject: subject,
          body_html: body_html,
          body_text: body_text || strip_html(body_html),
          from_email: user.email,
          from_name: user.name,
          to_email: customer.email,
          to_name: customer.name,
          status: 'sent',
          sent_at: Time.current,
          has_attachments: attachments.any?
        )
        
        # Create EmailAttachment records if needed
        if attachments.any?
          attachments.each do |attachment|
            attachment_record = email.email_attachments.create!(
              filename: attachment[:filename],
              content_type: attachment[:content_type] || 'application/octet-stream',
              attachment_id: "#{result.id}_#{attachment[:filename]}",
              size: File.size(attachment[:path])
            )
            
            # Attach the file
            attachment_record.file.attach(
              io: File.open(attachment[:path]),
              filename: attachment[:filename],
              content_type: attachment[:content_type]
            )
          end
        end
        
        # Create a customer activity record
        customer.customer_activities.create!(
          action: 'email_sent',
          details: "Email sent: #{subject}",
          user: user
        )
        
        return email
      end
      
      false
    rescue Google::Apis::AuthorizationError => e
      refresh_token
      retry
    rescue => e
      Rails.logger.error("Error sending email: #{e.message}")
      false
    end
  end
  
  # Download an attachment from Gmail
  def download_attachment(message_id, attachment_id)
    begin
      attachment = gmail.get_user_message_attachment('me', message_id, attachment_id)
      data = Base64.urlsafe_decode64(attachment.data.gsub(/-/,'+').gsub(/_/,'/'))
      return data
    rescue Google::Apis::AuthorizationError => e
      refresh_token
      retry
    rescue => e
      Rails.logger.error("Error downloading attachment: #{e.message}")
      nil
    end
  end
  
  private
  
  # Process a message from Gmail API
  def process_message(message, customer)
    # Skip if we already have this message in our database
    return if Email.exists?(message_id: message.id)
    
    # Get message details
    headers = message.payload.headers
    
    # Get subject
    subject = headers.find { |h| h.name.downcase == 'subject' }&.value || ''
    
    # Get from and to information
    from_header = headers.find { |h| h.name.downcase == 'from' }&.value || ''
    to_header = headers.find { |h| h.name.downcase == 'to' }&.value || ''
    
    # Parse from and to
    from_email, from_name = parse_email_address(from_header)
    to_email, to_name = parse_email_address(to_header)
    
    # Determine if this is a sent or received email
    is_received = from_email.downcase != user.email.downcase
    
    # Get message body
    body_parts = extract_message_body(message.payload)
    
    # Check for attachments
    has_attachments = has_attachments?(message.payload)
    
    # Get additional metadata
    label_ids = message.label_ids&.join(',')
    snippet = message.snippet || ""
    
    # Create the email record
    email = Email.create!(
      customer: customer,
      user: user,
      message_id: message.id,
      gmail_thread_id: message.thread_id,
      subject: subject,
      body_html: body_parts[:html],
      body_text: body_parts[:text],
      from_email: from_email,
      from_name: from_name,
      to_email: to_email,
      to_name: to_name,
      status: is_received ? 'received' : 'sent',
      sent_at: is_received ? nil : Time.at(message.internal_date / 1000.0),
      received_at: is_received ? Time.at(message.internal_date / 1000.0) : nil,
      has_attachments: has_attachments,
      snippet: snippet,
      label_ids: label_ids
    )
    
    # Save raw message data
    save_raw_message(email, message.raw)
    
    # Process attachments if any
    if has_attachments
      process_attachments(message.payload, email)
    end
    
    email
  end
  
  # Parse an email address string like "John Doe <john@example.com>"
  def parse_email_address(email_string)
    if email_string =~ /(.*)<(.*)>/
      name = $1.strip
      email = $2.strip
      [email, name]
    else
      [email_string.strip, nil]
    end
  end
  
  # Extract HTML and plain text parts from message
  def extract_message_body(payload)
    body = { html: nil, text: nil }
    
    if payload.mime_type == 'text/plain'
      body[:text] = decode_body(payload.body)
    elsif payload.mime_type == 'text/html'
      body[:html] = decode_body(payload.body)
    elsif payload.parts.present?
      payload.parts.each do |part|
        if part.mime_type == 'text/plain'
          body[:text] = decode_body(part.body)
        elsif part.mime_type == 'text/html'
          body[:html] = decode_body(part.body)
        elsif part.mime_type == 'multipart/alternative' || part.mime_type == 'multipart/related'
          # Recursively handle nested multipart messages
          nested_body = extract_message_body(part)
          body[:html] ||= nested_body[:html]
          body[:text] ||= nested_body[:text]
        end
      end
    end
    
    # If we only have HTML, generate plain text
    if body[:html].present? && body[:text].blank?
      body[:text] = strip_html(body[:html])
    end
    
    # If we only have plain text, convert to basic HTML
    if body[:text].present? && body[:html].blank?
      body[:html] = "<pre>#{body[:text]}</pre>"
    end
    
    body
  end
  
  # Check if a message has attachments
  def has_attachments?(payload)
    # Safely check if body has attachmentId property before accessing it
    return true if payload.body && payload.body.respond_to?(:attachmentId) && payload.body.attachmentId.present?
    
    if payload.parts.present?
      payload.parts.any? do |part|
        # Safely check part body
        (part.body && part.body.respond_to?(:attachmentId) && part.body.attachmentId.present?) || 
        (part.filename.present? && part.filename != '') ||
        (part.parts.present? && has_attachments?(part))
      end
    else
      false
    end
  end
  
  # Process and save attachments from a message
  def process_attachments(payload, email)
    # Safely check for attachmentId
    if payload.body && payload.body.respond_to?(:attachmentId) && 
       payload.body.attachmentId.present? && 
       payload.filename.present? && payload.filename != ''
      save_attachment(email, payload.body.attachmentId, payload.filename, payload.mime_type)
    end
    
    return unless payload.parts.present?
    
    payload.parts.each do |part|
      # Safely check part body for attachmentId
      if part.body && part.body.respond_to?(:attachmentId) && 
         part.body.attachmentId.present? && 
         part.filename.present? && part.filename != ''
        save_attachment(email, part.body.attachmentId, part.filename, part.mime_type)
      elsif part.parts.present?
        process_attachments(part, email)
      end
    end
  end
  
  # Save an attachment to the database
  def save_attachment(email, attachment_id, filename, mime_type)
    # Download the attachment data
    data = download_attachment(email.message_id, attachment_id)
    return unless data
    
    # Create a temporary file
    temp_file = Tempfile.new(['attachment', File.extname(filename)])
    temp_file.binmode
    temp_file.write(data)
    temp_file.rewind
    
    # Create the attachment record
    attachment = email.email_attachments.create!(
      filename: filename,
      content_type: mime_type,
      attachment_id: "#{email.message_id}_#{attachment_id}",
      size: data.bytesize
    )
    
    # Attach the file
    attachment.file.attach(
      io: temp_file,
      filename: filename,
      content_type: mime_type
    )
    
    # Clean up the temp file
    temp_file.close
    temp_file.unlink
  end
  
  # Save the raw message content
  def save_raw_message(email, raw)
    return unless raw
    
    # Decode the raw message
    decoded = raw.is_a?(String) ? raw : Base64.urlsafe_decode64(raw)
    
    # Create a temporary file
    temp_file = Tempfile.new(['email', '.eml'])
    temp_file.binmode
    temp_file.write(decoded)
    temp_file.rewind
    
    # Attach the raw message
    email.raw_message.attach(
      io: temp_file,
      filename: "#{email.message_id}.eml",
      content_type: 'message/rfc822'
    )
    
    # Clean up the temp file
    temp_file.close
    temp_file.unlink
  end
  
  # Decode base64 encoded body
  def decode_body(body)
    # Body might be nil or doesn't respond to data
    return nil if body.nil? || !body.respond_to?(:data)
    # Data might be nil
    return nil if body.data.nil?
    
    begin
      # Decode the body
      decoded = Base64.urlsafe_decode64(body.data.gsub(/-/,'+').gsub(/_/,'/'))
      decoded.force_encoding('UTF-8')
      
      # If not valid UTF-8, try other encodings
      unless decoded.valid_encoding?
        # Try ISO-8859-1
        decoded = decoded.force_encoding('ISO-8859-1').encode('UTF-8')
      end
      
      decoded
    rescue ArgumentError => e
      Rails.logger.error("Base64 decoding error: #{e.message}")
      # If decoding fails, return empty string
      ''
    rescue Encoding::UndefinedConversionError => e
      Rails.logger.error("Encoding conversion error: #{e.message}")
      # If encoding conversion fails, try to return raw data
      body.data.to_s
    rescue => e
      Rails.logger.error("Unexpected error in decode_body: #{e.message}")
      # If all decoding fails, return empty string
      ''
    end
  end
  
  # Strip HTML tags for plain text
  def strip_html(html)
    return '' unless html
    
    # Simple HTML stripping - for more complex cases, consider using a HTML parser
    html.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end
  
  # Set up the OAuth2 client
  def auth_client
    client = Signet::OAuth2::Client.new(
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      client_id: Rails.application.credentials.dig(:GOOGLE_CLIENT_ID),
      client_secret: Rails.application.credentials.dig(:GOOGLE_CLIENT_SECRET),
      scope: Google::Apis::GmailV1::AUTH_GMAIL_MODIFY
    )
    
    # Set tokens from user
    client.access_token = user.google_token
    client.refresh_token = user.google_refresh_token
    
    # Set expiration
    if user.google_token_expires_at.present?
      client.expires_at = user.google_token_expires_at.to_i
    end
    
    client
  end
  
  # Refresh the OAuth token if expired
  def refresh_token
    client = auth_client
    client.refresh!
    
    # Update user tokens
    user.update!(
      google_token: client.access_token,
      google_token_expires_at: Time.at(client.expires_at)
    )
    
    # Update the Gmail client authorization
    @gmail.authorization = client
  end
end 