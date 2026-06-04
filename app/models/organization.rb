class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :features, class_name: "OrganizationFeature", dependent: :destroy
  has_many :taxonomies, dependent: :destroy

  has_one_attached :logo

  RESERVED_SUBDOMAINS = %w[www admin app api mail ftp blog help support staging crm].freeze
  HEX_COLOR = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/
  DEFAULT_PRIMARY_COLOR = "#1E3A8A".freeze
  DEFAULT_ACCENT_COLOR  = "#10B981".freeze

  validates :name, presence: true
  validates :subdomain,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/,
                      message: "may only contain lowercase letters, numbers, and hyphens" },
            length: { in: 2..63 },
            exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :primary_color, :accent_color,
            format: { with: HEX_COLOR, message: "must be a valid hex color (e.g. #1E3A8A)" }
  validate :logo_is_an_image

  before_validation :normalize_subdomain
  before_validation :normalize_colors

  def initial
    name.to_s.strip[0]&.upcase || "?"
  end

  def feature(key)
    features.find_by(key: key.to_s)
  end

  def feature_enabled?(key)
    feature(key)&.enabled? || false
  end

  def calling
    @calling ||= Calling::Facade.new(self) if defined?(Calling::Facade)
  end

  # Convenience: active taxonomy values for one kind, in display order.
  # Replaces direct reads of Customer::LEAD_SOURCES etc. in views.
  def taxonomy_values(kind)
    taxonomies.where(kind: kind.to_s, archived: false).order(:position, :id).pluck(:name)
  end

  def taxonomy_options(kind)
    taxonomy_values(kind).map { |n| [ n, n ] }
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.strip.downcase.presence
  end

  def normalize_colors
    self.primary_color = primary_color.to_s.strip.presence || DEFAULT_PRIMARY_COLOR
    self.accent_color  = accent_color.to_s.strip.presence  || DEFAULT_ACCENT_COLOR
  end

  def logo_is_an_image
    return unless logo.attached?

    unless logo.content_type.in?(%w[image/png image/jpeg image/svg+xml image/webp])
      errors.add(:logo, "must be a PNG, JPEG, SVG, or WebP image")
    end
  end
end
