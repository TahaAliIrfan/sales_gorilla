require "pdf-reader"
require "docx"

# Pulls plain text out of a file a user uploads in the Proposal Generator chat
# (requirements docs, notes) so it can be fed to the model as context. Handles
# PDF, .docx, and plain text/markdown/csv. Returns nil for anything unsupported
# (e.g. images) or on any failure — the chat still works without it.
class ProposalFileExtractor
  MAX_CHARS = 20_000

  def self.extract(uploaded)
    new(uploaded).extract
  end

  def initialize(uploaded)
    @file = uploaded
  end

  def extract
    return nil if @file.blank?

    name = @file.original_filename.to_s.downcase
    type = @file.content_type.to_s

    text =
      if type.include?("pdf") || name.end_with?(".pdf")
        pdf_text
      elsif name.end_with?(".docx") || type.include?("wordprocessingml")
        docx_text
      elsif type.start_with?("text/") || name.match?(/\.(txt|md|markdown|csv)\z/)
        @file.read.to_s
      end

    text.presence&.strip&.slice(0, MAX_CHARS)
  rescue => e
    Rails.logger.error("ProposalFileExtractor error for #{@file&.original_filename}: #{e.message}")
    nil
  end

  private

  def pdf_text
    reader = PDF::Reader.new(StringIO.new(@file.read))
    reader.pages.map(&:text).join("\n")
  end

  def docx_text
    doc = Docx::Document.open(StringIO.new(@file.read))
    doc.paragraphs.map(&:text).reject(&:blank?).join("\n")
  end
end
