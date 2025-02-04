class OidcUser < ApplicationRecord
  has_many :email_subscriptions, dependent: :destroy

  validates :sub, presence: true

  before_destroy :create_tombstone

  def self.find_by_sub!(sub, legacy_sub: nil)
    if legacy_sub
      find_by(sub:) || find_by!(legacy_sub:).tap do |legacy_user|
        legacy_user.update!(sub:)
      end
    else
      find_by!(sub:)
    end
  end

  def self.find_or_create_by_sub!(sub, legacy_sub: nil)
    transaction do
      find_by_sub!(sub, legacy_sub:)
    rescue ActiveRecord::RecordNotFound
      LogoutNotice.new(sub).remove
      create!(sub:, legacy_sub:)
    end
  end

  def get_attributes_by_name(names = [])
    names.index_with { |name| self[name] }.compact
  end

  def create_tombstone
    Tombstone.create!(sub:)
  end
end
