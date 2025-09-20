class Tenant < ApplicationRecord
  class NotFound < StandardError; end
  class AccessDenied < StandardError; end

  RESERVED = %w[www admin api billing].freeze

  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }
  validate :subdomain_not_reserved

  before_validation :normalize_subdomain

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.downcase.strip
  end

  def subdomain_not_reserved
    errors.add(:subdomain, 'is reserved') if RESERVED.include?(subdomain)
  end
end
