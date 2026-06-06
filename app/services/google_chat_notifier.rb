require 'net/http'
require 'json'

class GoogleChatNotifier
  def self.send_alert(title:, message:, severity: 'warning')
    webhook_url = Rails.application.credentials.google_chat_webhook_url
    return false unless webhook_url.present?

    begin
      uri = URI(webhook_url)

      # Color codes for different severity levels
      color = case severity
              when 'critical' then '#FF0000' # Red
              when 'warning' then '#FFA500'  # Orange
              when 'info' then '#00FF00'     # Green
              else '#FFA500'
              end

      payload = {
        cards: [{
          header: {
            title: "🚨 #{title}",
            subtitle: "CRM Server Alert",
            imageUrl: "https://www.gstatic.com/images/branding/product/1x/googleg_32dp.png"
          },
          sections: [{
            widgets: [
              {
                keyValue: {
                  topLabel: "Severity",
                  content: severity.upcase,
                  contentMultiline: false,
                  icon: severity == 'critical' ? 'STAR' : 'DESCRIPTION'
                }
              },
              {
                textParagraph: {
                  text: "<b>Message:</b><br>#{message}"
                }
              },
              {
                keyValue: {
                  topLabel: "Time",
                  content: Time.current.strftime("%Y-%m-%d %H:%M:%S %Z"),
                  contentMultiline: false,
                  icon: 'CLOCK'
                }
              },
              {
                keyValue: {
                  topLabel: "Environment",
                  content: Rails.env,
                  contentMultiline: false
                }
              }
            ]
          }]
        }]
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      if response.code.to_i == 200
        Rails.logger.info("Successfully sent Google Chat alert: #{title}")
        true
      else
        Rails.logger.error("Failed to send Google Chat alert. Status: #{response.code}, Body: #{response.body}")
        false
      end
    rescue => e
      Rails.logger.error("Error sending Google Chat notification: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  # Specific alert methods
  def self.server_slow_alert(details)
    send_alert(
      title: 'Server Performance Degraded',
      message: details,
      severity: 'warning'
    )
  end

  def self.server_crashed_alert(details)
    send_alert(
      title: 'Server Crash Detected',
      message: details,
      severity: 'critical'
    )
  end

  def self.high_memory_alert(details)
    send_alert(
      title: 'High Memory Usage',
      message: details,
      severity: 'warning'
    )
  end

  def self.high_cpu_alert(details)
    send_alert(
      title: 'High CPU Usage',
      message: details,
      severity: 'warning'
    )
  end

  def self.database_slow_alert(details)
    send_alert(
      title: 'Database Performance Issue',
      message: details,
      severity: 'warning'
    )
  end

  def self.health_check_failed_alert(details)
    send_alert(
      title: 'Health Check Failed',
      message: details,
      severity: 'critical'
    )
  end
end
