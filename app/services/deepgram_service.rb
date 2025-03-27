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

    response_data = JSON.parse(response.body)


    puts response_data

    return { error: "Invalid response from Deepgram" } unless response_data.is_a?(Hash) && response_data['results'].is_a?(Hash)

    {
      metadata: response_data['metadata'],
      results: {
        channels: (response_data.dig('results', 'channels') || []).map do |channel|
          next unless channel.is_a?(Hash)
          
          {
            alternatives: (channel['alternatives'] || []).map do |alt|
              next unless alt.is_a?(Hash)
              
              {
                transcript: alt['transcript'],
                confidence: alt['confidence'],
                words: (alt['words'] || []).map do |word|
                  next unless word.is_a?(Hash)
                  
                  {
                    word: word['word'],
                    start: word['start'],
                    end: word['end'],
                    confidence: word['confidence'],
                    speaker: word['speaker'],
                    speaker_confidence: word['speaker_confidence'],
                    punctuated_word: word['punctuated_word']
                  }
                end.compact
              }
            end.compact
          }
        end.compact
      }
    }
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