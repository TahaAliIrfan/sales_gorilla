class DeepgramService
  BASE_URL = 'https://api.deepgram.com'

  def transcribe(recording_url)
    response = api_connection.post('/v1/listen') do |req|
      req.params['tier'] = 'nova'
      req.params['language'] = 'en'
      req.params['model'] = 'phonecall'
      req.params['punctuate'] = 'true'
      req.params['diarize'] = true
      req.params['utterances'] = true
      req.body = { url: recording_url }.to_json
    end

    JSON.parse(response.body)
  end

  private

  def api_connection
    @api_connection ||= Faraday.new(
      url: BASE_URL,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Token #{Rails.application.credentials.dig(:DEEPGRAM_API)}"
      }
    )
  end
end