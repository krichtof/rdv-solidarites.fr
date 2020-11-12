class PlageOuverture < ApplicationRecord
  include RecurrenceConcern
  include WebhookDeliverable

  belongs_to :organisation
  belongs_to :agent
  belongs_to :lieu
  has_and_belongs_to_many :motifs, -> { distinct }

  after_create :notify_agent_plage_ouverture_created
  after_update :notify_agent_plage_ouverture_updated
  after_save :refresh_plage_ouverture_expired_cached

  validate :end_after_start
  validates :motifs, :title, presence: true
  # caution :warn_overlapping_plage_ouverture

  has_many :webhook_endpoints, through: :organisation

  scope :expired, -> { where(expired_cached: true) }
  scope :not_expired, -> { where(expired_cached: false) }

  def notify_agent_plage_ouverture_created
    Agents::PlageOuvertureMailer.plage_ouverture_created(self).deliver_later
  end

  def notify_agent_plage_ouverture_updated
    Agents::PlageOuvertureMailer.plage_ouverture_updated(self).deliver_later
  end

  def ical_uid
    "plage_ouverture_#{id}@#{BRAND}"
  end

  def time_shift
    Tod::Shift.new(start_time, end_time)
  end

  def time_shift_duration_in_min
    time_shift.duration / 60
  end

  def self.for_motif_and_lieu_from_date_range(motif_name, lieu, inclusive_date_range)
    PlageOuverture
      .includes(:motifs_plageouvertures)
      .where(lieu: lieu)
      .where("plage_ouvertures.first_day <= ?", inclusive_date_range.end)
      .joins(:motifs)
      .where(motifs: { name: motif_name, organisation_id: lieu.organisation_id })
      .includes(:motifs, agent: :absences)
  end

  def expired?
    # Use .expired_cached? for performance
    (recurrence.nil? && first_day < Date.today) ||
      (recurrence.present? && recurrence.to_hash[:until].present? && recurrence.to_hash[:until].to_date < Date.today)
  end

  def available_motifs
    Motif.available_motifs_for_organisation_and_agent(organisation, agent)
  end

  def refresh_plage_ouverture_expired_cached
    update_column(:expired_cached, expired?)
  end

  def time_range
    return nil unless exceptionnelle?

    starts_at..ends_at
  end

  def weeks_difference_with(other)
    other.first_day.cweek - first_day.cweek +
      ((other.first_day.year - first_day.year) * 52)
  end

  def overlaps?(other)
    if exceptionnelle? && other.exceptionnelle?
      starts_at < other.ends_at && ends_at > other.starts_at
    elsif recurring? && other.exceptionnelle?
      return false if defined?(end_day) && end_day.present? && other.exceptionnelle? && other.first_day < end_day

      return false unless recurrence_opts[:day].include?(other.first_day.wday)

      return false unless recurrence_opts[:every] == :week # months unsupported yet

      return false if weeks_difference_with(other) % recurrence_opts[:interval] != 0

      start_time < other.end_time && end_time > other.start_time
    end
  end

  private

  def end_after_start
    return if end_time.blank? || start_time.blank?

    errors.add(:end_time, "doit être après l'heure de début") if end_time <= start_time
  end

  def warn_overlapping_plage_ouverture
    return if false
    warnings.add(:base, "Une plage d'ouverture existante recoupe ces dates.", active: true)
    warnings.add(:base, "Une plage d'ouverture existante recoupe ces dates.", active: true)
  end
end
