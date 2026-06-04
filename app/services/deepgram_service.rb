class DeepgramService
  BASE_URL = "https://api.deepgram.com"

  def transcribe(recording)
    response = api_connection.post("/v1/listen") do |req|
      req.params["tier"] = "nova"
      req.params["language"] = "en"
      req.params["model"] = "phonecall"
      req.params["punctuate"] = "true"
      req.params["diarize"] = true
      req.params["utterances"] = true
      req.body = { url: recording.audio_file.url }.to_json
    end

    result = JSON.parse(response.body)

    recording.update!(
      transcription: condense_speaker_utterances(result["results"]["utterances"]).compact,
      transcription_status: :completed
    )
  end

  private


  def utterance_mapping(utterance)
    { speaker: utterance["speaker"] || utterance["channel"], transcript: utterance["transcript"],
      start: utterance["start"], end: utterance["end"] }
  end

  def concat_speaker_utterances(left, right)
    left[:transcript].concat(" ", right[:transcript])
    left[:end] = right[:end]
  end

  def condense_speaker_utterances(utterances)
    utterance_blocks = utterances.map { |utterance| utterance_mapping(utterance) }
    utterance_blocks.drop(1).reduce([ utterance_blocks.first ]) do |memo, utterance|
      if utterance[:speaker] == memo.last[:speaker]
        memo.tap { |m| concat_speaker_utterances(m.last, utterance) }
      else
        memo << utterance
      end
    end
  end



  def api_connection
    @api_connection ||= Faraday.new(
      url: BASE_URL,
      headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Token #{Rails.application.credentials.dig(:DEEPGRAM_API)}"
      }
    )
  end
end
