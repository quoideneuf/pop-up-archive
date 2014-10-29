class Collection < ActiveRecord::Base
  resourcify :is_resource_of

  acts_as_paranoid

  # include ActiveModel::ForbiddenAttributesProtection
  attr_accessible :title, :description, :items_visible_by_default, :creator, :creator_id, :storage, :default_storage_id

  belongs_to :default_storage, class_name: "StorageConfiguration"
  belongs_to :upload_storage, class_name: "StorageConfiguration"
  belongs_to :creator, class_name: "User"

  has_many :collection_grants, dependent: :destroy
  has_many :uploads_collection_grants, class_name: 'CollectionGrant', conditions: {uploads_collection: true}
  #has_many :users, through: :collection_grants # TODO this is broken
  has_many :items, dependent: :destroy
  has_many :audio_files, through: :items

  validates_presence_of :title

  validate :validate_storage

  scope :is_public, where(items_visible_by_default: true)

  before_validation :set_defaults

  after_commit :grant_to_creator, on: :create

  # def self.visible_to_user(user)
  #   if user.present?
  #     grants = CollectionGrant.arel_table
  #     (includes(:collection_grants).where(grants[:user_id].eq(user.id).or(arel_table[:items_visible_by_default].eq(true))))
  #   else
  #     is_public
  #   end
  # end

  # returns object to which this audio_file should be accounted.
  # should be a User or Organization that has role 'owner' on the Collection
  def billable_to
    # memoize, given caveats in http://cmme.org/tdumitrescu/blog/2014/01/careful-what-you-memoize/
    return @_billable_to if @_billable_to

    # find the first owner via roles. 
    # croak if there is more than one.
    owner_role = get_owner_role
    if !owner_role
      # create one, assigning to the creator or oldest grantee
      owner = creator ? creator.entity : collection_grants.order('created_at asc').first.collector.entity
      owner_role = Role.new
      owner_role.name = :owner
      owner_role.resource = self
      owner_role.save!
      owner.add_role :owner, self
      owner.save!
      @_billable_to = owner
    else
      @_billable_to = owner_role.single_designee
    end

    return @_billable_to
  end

  def get_owner_role
    owner_roles = is_resource_of.where(:name => :owner)
    if owner_roles.size > 1 
      raise "More than one owner role defined for collection #{id}"
    end
    return owner_roles.first
  end

  def set_owner(user_or_org)
    cur_owner = billable_to
    cur_owner_role = get_owner_role
    if cur_owner_role
      cur_owner.remove_role :owner, self
    end
    user_or_org.add_role :owner, self
    user_or_org.save!
    # nullify cache
    @_billable_to = nil
    return user_or_org
  end

  def storage=(provider)
    if (provider == 'InternetArchive') && (!default_storage || (default_storage.provider != 'InternetArchive'))
      self.default_storage = StorageConfiguration.archive_storage
    end
    set_storage
  end

  def storage
    default_storage.provider
  end

  def validate_storage
    errors.add(:default_storage, "must be set") if !default_storage
    errors.add(:upload_storage, "must be set when default does not allow direct upload") if (!upload_storage && !default_storage.direct_upload?)
  end

  def upload_to
    upload_storage || default_storage
  end

  def set_storage
    self.default_storage = StorageConfiguration.popup_storage if !default_storage
    if default_storage.direct_upload?
      self.upload_storage = nil
    else
      self.upload_storage = StorageConfiguration.popup_storage if !upload_storage
    end
  end

  def set_defaults
    self.set_storage
    self.copy_media = true if self.copy_media.nil?
  end

  def grant_to_creator
    return unless creator
    collector = creator.organization || creator
    collector.collections << self unless creator.collections.include? self || creator.uploads_collection == self
  end

  def uploads_collection?
    uploads_collection_grants.present?
  end

  def used_metered_storage
    @_used_metered_storage ||= (items.map{|item| item.audio_files.where(metered: true).sum(:duration) }.inject(:+) || 0)
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= (items.map{|item| item.audio_files.where(metered: false).sum(:duration) }.inject(:+) || 0)
  end
end
