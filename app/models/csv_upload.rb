class CsvUpload < ApplicationRecord
  belongs_to :user

  validates :upload_token, presence: true, uniqueness: true
  validates :original_filename, presence: true
  validates :file_path, presence: true
  validates :headers, presence: true
  validates :total_rows, presence: true, numericality: { greater_than: 0 }
  validates :lead_source, inclusion: { in: Customer::LEAD_SOURCES.values }, allow_blank: true

  serialize :headers, coder: JSON
  serialize :sample_rows, coder: JSON
  serialize :suggested_mappings, coder: JSON

  before_validation :generate_upload_token, on: :create
  before_destroy :cleanup_file

  scope :expired, -> { where("created_at < ?", 24.hours.ago) }

  def self.cleanup_expired
    expired.find_each(&:destroy)
  end

  def file_exists?
    File.exist?(file_path)
  end

  def read_csv_content
    return nil unless file_exists?
    File.read(file_path)
  end

  def expired?
    created_at < 24.hours.ago
  end

  private

  def generate_upload_token
    self.upload_token = SecureRandom.hex(16)
  end

  def cleanup_file
    File.delete(file_path) if file_exists?
  rescue => e
    Rails.logger.error "Failed to cleanup CSV file #{file_path}: #{e.message}"
  end
end
