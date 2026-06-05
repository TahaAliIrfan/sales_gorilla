require "google/apis/gmail_v1"
require "base64"
require "mail"
require "securerandom"
require "uri"

class GmailService
  attr_reader :gmail, :user

  def initialize(user)
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.client_options.application_name = "Tecaudex CRM"
    @gmail.authorization = auth_client
  end

  # Fetch emails for a specific customer
  def fetch_emails_for_customer(customer, max_results = 100)
    return [] unless customer.email.present?

    # Search for emails to or from the customer
    query = "(to:#{customer.email} OR from:#{customer.email})"
    begin
      messages = gmail.list_user_messages("me", q: query, max_results: max_results)
      return [] unless messages&.messages

      processed_emails = []

      messages.messages.each do |message_data|
        begin
          # Get the full message
          message = gmail.get_user_message("me", message_data.id, format: "full")

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
  def send_email(customer, subject, body_html, body_text = nil, attachments = [], thread_options = {})
    return false unless customer.email.present?

    Rails.logger.info("Sending email to #{customer.email} with #{attachments.length} attachments")

    begin
      # Inject the open-tracking pixel before building the MIME structure.
      # The token is generated here and re-used when the Email row is created
      # so the pixel hit (which carries the token) maps to this exact email.
      tracking_token = SecureRandom.urlsafe_base64(24)
      body_html = EmailTrackingPixel.inject(
        body_html,
        tracking_token: tracking_token,
        base_url: tracking_base_url
      )

      # Generate plain text from HTML if not provided
      plain_text = body_text.presence || strip_html(body_html)

      # Prepare attachment data first
      attachment_data = []
      attachments.each do |attachment|
        file_content = if attachment[:content]
          attachment[:content]
        elsif attachment[:path]
          File.binread(attachment[:path])
        else
          next
        end

        # Force binary encoding
        file_content = file_content.dup.force_encoding("BINARY") if file_content.is_a?(String)

        Rails.logger.info("Preparing attachment: #{attachment[:filename]} (#{attachment[:content_type]}), size: #{file_content.bytesize} bytes")

        attachment_data << {
          filename: attachment[:filename],
          content_type: attachment[:content_type] || "application/octet-stream",
          content: file_content,
          size: attachment[:size] || file_content.bytesize
        }
      end

      # Build email with proper MIME structure
      mail = Mail.new
      mail.from = "#{user.name} <#{user.email}>"
      mail.to = customer.email
      mail.subject = subject

      # Add reply headers if this is a reply
      if thread_options[:in_reply_to].present?
        mail.in_reply_to = thread_options[:in_reply_to]
        mail.references = thread_options[:in_reply_to]
      end

      Rails.logger.info("Mail TO: #{mail.to.inspect}")
      Rails.logger.info("Mail FROM: #{mail.from.inspect}")
      Rails.logger.info("Mail SUBJECT: #{mail.subject.inspect}")

      # Build the email structure based on whether there are attachments
      if attachment_data.any?
        # For emails with attachments, we need a multipart/mixed structure:
        # multipart/mixed
        #   └── multipart/alternative (text + html)
        #   └── attachment1
        #   └── attachment2...

        # Create the multipart/alternative part for text/html content
        alternative_part = Mail::Part.new
        alternative_part.content_type = "multipart/alternative"

        # Add text part to alternative
        text_part = Mail::Part.new
        text_part.content_type = "text/plain; charset=UTF-8"
        text_part.body = plain_text
        alternative_part.add_part(text_part)

        # Add HTML part to alternative
        html_part = Mail::Part.new
        html_part.content_type = "text/html; charset=UTF-8"
        html_part.body = body_html
        alternative_part.add_part(html_part)

        # Set the mail as multipart/mixed and add the alternative part
        mail.content_type = "multipart/mixed"
        mail.body = nil # Clear body to add parts
        mail.add_part(alternative_part)

        # Add each attachment as a separate part
        attachment_data.each do |att|
          attachment_part = Mail::Part.new
          attachment_part.content_type = "#{att[:content_type]}; name=\"#{att[:filename]}\""
          attachment_part.content_disposition = "attachment; filename=\"#{att[:filename]}\""
          attachment_part.content_transfer_encoding = "base64"
          attachment_part.body = Base64.strict_encode64(att[:content])
          mail.add_part(attachment_part)
        end

        Rails.logger.info("Built multipart/mixed email with #{attachment_data.length} attachments")
      else
        # For emails without attachments, use simple text_part/html_part
        mail.text_part = Mail::Part.new
        mail.text_part.content_type = "text/plain; charset=UTF-8"
        mail.text_part.body = plain_text

        mail.html_part = Mail::Part.new
        mail.html_part.content_type = "text/html; charset=UTF-8"
        mail.html_part.body = body_html

        Rails.logger.info("Built multipart/alternative email without attachments")
      end

      Rails.logger.info("Mail content type: #{mail.content_type}")
      Rails.logger.info("Mail parts count: #{mail.parts.count}")

      # Finalize the mail object
      mail.ready_to_send!

      # Get the raw message
      raw_message = mail.to_s
      Rails.logger.info("Raw message size: #{raw_message.bytesize} bytes")

      # Debug: Log first 1000 chars to see headers
      Rails.logger.info("Raw message headers:\n#{raw_message[0..1000]}")

      # Debug: Check if attachments are in the encoded message
      attachment_data.each do |att|
        if raw_message.include?(att[:filename])
          Rails.logger.info("✓ Attachment '#{att[:filename]}' found in raw message")
        else
          Rails.logger.error("✗ Attachment '#{att[:filename]}' NOT found in raw message!")
        end
      end

      # Use upload_source approach (this was working before)
      send_options = {
        upload_source: StringIO.new(raw_message),
        content_type: "message/rfc822"
      }

      # Add thread ID if this is a reply
      if thread_options[:thread_id].present?
        send_options[:thread_id] = thread_options[:thread_id]
      end

      Rails.logger.info("Sending message via Gmail API...")
      result = gmail.send_user_message("me", **send_options)

      if result
        # Create an Email record in the database. Use the token we generated
        # before injecting the pixel so opens map back to this row.
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
          status: "sent",
          sent_at: Time.current,
          has_attachments: attachment_data.any?,
          tracking_token: tracking_token
        )

        # Attach files directly using Active Storage
        if attachment_data.any?
          attachment_data.each do |att|
            email.attachments.attach(
              io: StringIO.new(att[:content]),
              filename: att[:filename],
              content_type: att[:content_type]
            )
          end
        end

        # Create a customer activity record
        customer.customer_activities.create!(
          action: "email_sent",
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
      attachment = gmail.get_user_message_attachment("me", message_id, attachment_id)

      total_chars = attachment.data.length
      base64_chars = attachment.data.scan(/[A-Za-z0-9\+\/\-\_\=]/).length
      base64_ratio = (base64_chars.to_f / total_chars * 100).round(2)
      Rails.logger.info("Base64-like characters: #{base64_chars}/#{total_chars} (#{base64_ratio}%)")

      data = decode_base64_data(attachment.data)

      file_type = detect_file_type_from_bytes(data)

      data
    rescue Google::Apis::AuthorizationError => e
      refresh_token
      retry
    rescue => e
      Rails.logger.error("Error downloading attachment: #{e.message}")
      Rails.logger.error(e.backtrace.first(3).join("\n"))
      nil
    end
  end

  # Detect file type from magic bytes
  def detect_file_type_from_bytes(data)
    return "unknown" if data.nil? || data.empty?

    first_bytes = data.bytes.first(10)

    if first_bytes[0..2] == [ 0xFF, 0xD8, 0xFF ]
      "JPEG"
    elsif first_bytes[0..3] == [ 0x89, 0x50, 0x4E, 0x47 ]
      "PNG"
    elsif first_bytes[0..3] == [ 0x25, 0x50, 0x44, 0x46 ]
      "PDF"
    elsif first_bytes[0..3] == [ 0x50, 0x4B, 0x03, 0x04 ]
      "ZIP/DOCX/XLSX"
    elsif first_bytes[0..1] == [ 0x42, 0x4D ]
      "BMP"
    elsif first_bytes[0..3] == [ 0x47, 0x49, 0x46, 0x38 ]
      "GIF"
    else
      "unknown (starts with: #{first_bytes.map { |b| '%02x' % b }.join(' ')})"
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
    subject = headers.find { |h| h.name.downcase == "subject" }&.value || ""

    # Get from and to information
    from_header = headers.find { |h| h.name.downcase == "from" }&.value || ""
    to_header = headers.find { |h| h.name.downcase == "to" }&.value || ""

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
    label_ids = message.label_ids&.join(",")
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
      status: is_received ? "received" : "sent",
      sent_at: is_received ? nil : Time.at(message.internal_date / 1000.0),
      received_at: is_received ? Time.at(message.internal_date / 1000.0) : nil,
      has_attachments: has_attachments,
      snippet: snippet,
      label_ids: label_ids
    )

    # Save raw message data
    save_raw_message(email, message.raw)

    # Process attachments if any
    attachments_saved = process_attachments(message.payload, email)
    if attachments_saved.positive? && !has_attachments
      email.update(has_attachments: true)
    end

    email
  end

  # Parse an email address string like "John Doe <john@example.com>"
  def parse_email_address(email_string)
    if email_string =~ /(.*)<(.*)>/
      name = $1.strip
      email = $2.strip
      [ email, name ]
    else
      [ email_string.strip, nil ]
    end
  end

  # Extract HTML and plain text parts from message
  def extract_message_body(payload)
    body = { html: nil, text: nil }

    if payload.mime_type == "text/plain"
      body[:text] = decode_body(payload.body)
    elsif payload.mime_type == "text/html"
      body[:html] = decode_body(payload.body)
    elsif payload.parts.present?
      payload.parts.each do |part|
        if part.mime_type == "text/plain"
          body[:text] = decode_body(part.body)
        elsif part.mime_type == "text/html"
          body[:html] = decode_body(part.body)
        elsif part.mime_type == "multipart/alternative" || part.mime_type == "multipart/related"
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
    # Check if body has attachment_id (Google API uses snake_case)
    if payload.body
      att_id = get_attachment_id(payload.body)
      return true if att_id.present?
    end

    if payload.parts.present?
      payload.parts.any? do |part|
        # Check part body for attachment_id
        att_id = part.body ? get_attachment_id(part.body) : nil
        att_id.present? ||
        (part.filename.present? && part.filename != "") ||
        content_disposition_attachment?(part.headers) ||
        (part.parts.present? && has_attachments?(part))
      end
    else
      false
    end
  end

  # Helper to get attachment_id from body (handles both snake_case and camelCase)
  def get_attachment_id(body)
    return nil unless body

    # Try snake_case first (standard Ruby Google API client)
    if body.respond_to?(:attachment_id)
      return body.attachment_id
    end

    # Fallback to camelCase (some versions might use this)
    if body.respond_to?(:attachmentId)
      return body.attachmentId
    end

    nil
  end

  # Process and save attachments from a message
  def process_attachments(payload, email)
    Rails.logger.info("Processing attachments for email #{email.id}")
    attachments_saved = 0

    # Check payload body for attachment
    if payload.body
      att_id = get_attachment_id(payload.body)
      if att_id.present?
        filename = extract_filename(payload)
        Rails.logger.info("Found attachment at payload level: #{filename}")
        attachments_saved += 1 if save_attachment(email, att_id, filename, payload.mime_type)
      end
    end

    return attachments_saved unless payload.parts.present?

    payload.parts.each do |part|
      Rails.logger.info("Checking part: mime_type=#{part.mime_type}, filename=#{part.filename.inspect}")

      # Check if this part has an attachment
      if part.body
        att_id = get_attachment_id(part.body)
        if att_id.present?
          filename = extract_filename(part)
          Rails.logger.info("Found attachment: #{filename} (#{part.mime_type}), attachment_id: #{att_id}")
          attachments_saved += 1 if save_attachment(email, att_id, filename, part.mime_type)
        else
          # Some attachments have data directly in the body instead of attachment_id
          if part.body.respond_to?(:data) && part.body.data.present?
            filename = extract_filename(part, fallback_prefix: "inline")
            Rails.logger.info("Found inline attachment data for: #{filename}")
            attachments_saved += 1 if save_inline_attachment(email, part, filename)
          end
        end
      elsif part.parts.present?
        # Recursively process nested parts
        attachments_saved += process_attachments(part, email)
      end
    end

    attachments_saved
  end

  # Save an inline attachment (data is directly in the body, not via attachment_id)
  def save_inline_attachment(email, part, filename)
    begin
      # Decode the inline data
      data = decode_base64_data(part.body.data)

      Rails.logger.info("Decoded inline attachment: #{filename}, size: #{data.bytesize} bytes, encoding: #{data.encoding.name}")

      # Force binary encoding for attachment data
      binary_data = data.dup.force_encoding("BINARY")

      # Create StringIO with binary data
      io = StringIO.new(binary_data)
      io.set_encoding("BINARY")
      io.rewind  # Ensure we're at the beginning of the stream

      email.attachments.attach(
        io: io,
        filename: filename,
        content_type: part.mime_type
      )

      Rails.logger.info("✓ Saved inline attachment: #{filename} (#{binary_data.bytesize} bytes)")
      true
    rescue => e
      Rails.logger.error("Error saving inline attachment #{filename}: #{e.message}")
      Rails.logger.error(e.backtrace.first(3).join("\n"))
      false
    end
  end

  # Extract a filename from the part or its headers, with a fallback if missing
  def extract_filename(part, fallback_prefix: "attachment")
    return part.filename if part.respond_to?(:filename) && part.filename.present?

    filename = extract_filename_from_headers(part.headers)
    return filename if filename.present?

    att_id = part.body ? get_attachment_id(part.body) : nil
    identifier = att_id.presence || SecureRandom.hex(8)
    extension = extension_for_mime_type(part.mime_type)

    [ fallback_prefix, identifier ].compact.join("_") + (extension ? ".#{extension}" : "")
  end

  def extract_filename_from_headers(headers)
    return nil unless headers.present?

    disposition = headers.find { |h| h.name.to_s.downcase == "content-disposition" }&.value.to_s
    filename = parse_header_filename(disposition, "filename")
    return filename if filename.present?

    content_type = headers.find { |h| h.name.to_s.downcase == "content-type" }&.value.to_s
    parse_header_filename(content_type, "name")
  end

  def content_disposition_attachment?(headers)
    return false unless headers.present?
    disposition = headers.find { |h| h.name.to_s.downcase == "content-disposition" }&.value.to_s
    disposition.downcase.include?("attachment")
  end

  def parse_header_filename(header_value, key)
    return nil if header_value.blank?

    # Handle RFC 5987 (filename*=UTF-8''encoded)
    if header_value =~ /#{key}\*\s*=\s*([^;]+)/i
      raw = Regexp.last_match(1).to_s
      raw = raw.sub(/^UTF-8''/i, "").delete_prefix('"').delete_suffix('"')
      decoded = URI.decode_www_form_component(raw)
      return decoded if decoded.present?
    end

    if header_value =~ /#{key}\s*=\s*"?([^\";]+)"?/i
      return Regexp.last_match(1).to_s
    end

    nil
  end

  def extension_for_mime_type(mime_type)
    return nil if mime_type.blank?
    mime = Mime::Type.lookup(mime_type)
    ext = mime&.symbol
    ext.to_s if ext.present?
  end

  # Save an attachment directly to Active Storage
  def save_attachment(email, attachment_id, filename, mime_type)
    Rails.logger.info("Downloading attachment: #{filename} (attachment_id: #{attachment_id}, mime_type: #{mime_type})")

    # Download the attachment data
    data = download_attachment(email.message_id, attachment_id)

    unless data
      Rails.logger.error("Failed to download attachment: #{filename}")
      return false
    end

    Rails.logger.info("Downloaded #{data.bytesize} bytes for #{filename}")
    Rails.logger.info("Data encoding: #{data.encoding.name}, valid?: #{data.valid_encoding?}")

    begin
      # Force binary encoding for attachment data
      binary_data = data.dup.force_encoding("BINARY")

      # Create StringIO with binary data
      io = StringIO.new(binary_data)
      io.set_encoding("BINARY")
      io.rewind  # Ensure we're at the beginning of the stream

      Rails.logger.info("StringIO created with #{io.size} bytes, encoding: #{io.external_encoding.name}")

      # Attach the file directly using Active Storage
      email.attachments.attach(
        io: io,
        filename: filename,
        content_type: mime_type
      )

      # Verify the attachment was saved
      if email.attachments.attached?
        last_attachment = email.attachments.last
        Rails.logger.info("Active Storage blob created: #{last_attachment.blob.filename} (#{last_attachment.blob.byte_size} bytes)")
      end

      Rails.logger.info("✓ Saved attachment: #{filename} (#{binary_data.bytesize} bytes) to Active Storage")
      true
    rescue => e
      Rails.logger.error("Error saving attachment #{filename}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      false
    end
  end

  # Save the raw message content
  def save_raw_message(email, raw)
    return unless raw

    # Decode the raw message
    decoded = raw.is_a?(String) ? raw : decode_base64_data(raw)

    # Create a temporary file
    temp_file = Tempfile.new([ "email", ".eml" ])
    temp_file.binmode
    temp_file.write(decoded)
    temp_file.rewind

    # Attach the raw message
    email.raw_message.attach(
      io: temp_file,
      filename: "#{email.message_id}.eml",
      content_type: "message/rfc822"
    )

    # Clean up the temp file
    temp_file.close
    temp_file.unlink
  end

  # Decode Gmail's base64url-encoded data with proper padding handling
  def decode_base64_data(data)
    return nil if data.nil? || data.empty?

    # Check if data is already binary (not base64 encoded)
    # Base64 should only contain: A-Z, a-z, 0-9, +, /, -, _, and =
    # If we see common binary markers or encoding issues, it's likely already decoded
    if data.encoding == Encoding::ASCII_8BIT || data.encoding == Encoding::BINARY
      Rails.logger.info("Data is already in binary encoding, using as-is")
      return data.dup.force_encoding("BINARY")
    end

    # Check for common file signatures that indicate already-decoded binary data
    if data.start_with?("\xFF\xD8\xFF") || # JPEG
       data.start_with?("\x89PNG") || # PNG
       data.start_with?("%PDF") || # PDF
       data.start_with?("PK\x03\x04") || # ZIP/DOCX
       data.include?("JFIF") || data.include?("Exif") # JPEG markers
      Rails.logger.info("Data appears to be already decoded binary (detected file signature)")
      return data.dup.force_encoding("BINARY")
    end

    # Check if data looks like valid base64
    # Valid base64 should have mostly alphanumeric characters
    non_base64_chars = data.count("^\x00-\x7F") # Count non-ASCII characters
    if non_base64_chars > data.length * 0.1 # More than 10% non-ASCII
      Rails.logger.info("Data contains too many non-ASCII characters (#{non_base64_chars}/#{data.length}), treating as binary")
      return data.dup.force_encoding("BINARY")
    end

    decoded = nil

    begin
      # Gmail API returns base64url-encoded data (RFC 4648)
      # which uses - and _ instead of + and /
      # First, try standard urlsafe_decode64
      decoded = Base64.urlsafe_decode64(data)
      Rails.logger.info("Successfully decoded with urlsafe_decode64")
    rescue ArgumentError => e
      # If that fails, it might be due to missing padding
      # Add padding and try again
      begin
        # Calculate padding needed
        padding_needed = (4 - data.length % 4) % 4
        padded_data = data + ("=" * padding_needed)
        decoded = Base64.urlsafe_decode64(padded_data)
        Rails.logger.info("Successfully decoded with padding")
      rescue ArgumentError
        # If still failing, try standard base64 decode as fallback
        begin
          # Replace URL-safe characters with standard base64 characters
          standard_b64 = data.tr("-_", "+/")
          padding_needed = (4 - standard_b64.length % 4) % 4
          padded_data = standard_b64 + ("=" * padding_needed)
          decoded = Base64.decode64(padded_data)
          Rails.logger.info("Successfully decoded with standard base64")
        rescue => inner_e
          # Last resort: treat as binary
          Rails.logger.error("Failed all base64 decoding attempts: #{inner_e.message}")
          Rails.logger.info("Treating data as already-decoded binary")
          return data.dup.force_encoding("BINARY")
        end
      end
    end

    # Ensure the decoded data is in binary encoding
    decoded.force_encoding("BINARY") if decoded
    decoded
  end

  # Decode base64 encoded body
  def decode_body(body)
    # Body might be nil or doesn't respond to data
    return nil if body.nil? || !body.respond_to?(:data)
    # Data might be nil
    return nil if body.data.nil?

    begin
      # Decode the body
      decoded = decode_base64_data(body.data)
      decoded.force_encoding("UTF-8")

      # If not valid UTF-8, try other encodings
      unless decoded.valid_encoding?
        # Try ISO-8859-1
        decoded = decoded.force_encoding("ISO-8859-1").encode("UTF-8")
      end

      decoded
    rescue ArgumentError => e
      Rails.logger.error("Base64 decoding error: #{e.message}")
      # If decoding fails, return empty string
      ""
    rescue Encoding::UndefinedConversionError => e
      Rails.logger.error("Encoding conversion error: #{e.message}")
      # If encoding conversion fails, try to return raw data
      body.data.to_s
    rescue => e
      Rails.logger.error("Unexpected error in decode_body: #{e.message}")
      # If all decoding fails, return empty string
      ""
    end
  end

  # Strip HTML tags for plain text
  def strip_html(html)
    return "" unless html

    # Simple HTML stripping - for more complex cases, consider using a HTML parser
    html.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
  end

  # Set up the OAuth2 client
  def auth_client
    client = Signet::OAuth2::Client.new(
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://oauth2.googleapis.com/token",
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

  # Absolute base URL for the open-tracking pixel. Tries (in order):
  #   1. credentials[:email_tracking_base_url] — explicit override
  #   2. ActionMailer's default_url_options — usually set per env
  #   3. "https://crm.tecaudex.com" — production fallback
  def tracking_base_url
    return @tracking_base_url if defined?(@tracking_base_url)

    explicit = Rails.application.credentials.dig(:email_tracking_base_url)
    return @tracking_base_url = explicit if explicit.present?

    mailer = Rails.application.config.action_mailer.default_url_options || {}
    host = mailer[:host]
    if host.present?
      protocol = mailer[:protocol].presence || (host.include?("localhost") ? "http" : "https")
      port = mailer[:port].present? ? ":#{mailer[:port]}" : ""
      return @tracking_base_url = "#{protocol}://#{host}#{port}"
    end

    @tracking_base_url = "https://crm.tecaudex.com"
  end
end
