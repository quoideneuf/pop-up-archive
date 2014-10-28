class Organization < ActiveRecord::Base

  include Billable

  resourcify :is_resource_of

  # known bug with resourcify and rolify together
  # https://github.com/RolifyCommunity/rolify/issues/244
  # so we pass explicit association name to resourcify and let
  # rolify use the 'roles' association name.
  rolify

  attr_accessible :name

  serialize :transcript_usage_cache, HstoreCoder

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'

  has_many :users
  has_many :collection_grants, as: :collector
  has_many :collections, through: :collection_grants

  has_many :monthly_usages, as: :entity

  has_one  :uploads_collection_grant, class_name: 'CollectionGrant', as: :collector, conditions: {uploads_collection: true}
  has_one  :uploads_collection, through: :uploads_collection_grant, source: :collection

  after_commit :add_uploads_collection, on: :create

  scope :premium_usage_desc, :order => "cast(transcript_usage_cache->'premium_seconds' as int) desc"
  scope :premium_usage_asc, :order => "cast(transcript_usage_cache->'premium_seconds' as int) asc"

  ROLES = [:admin, :member]

  def owns_collection?(coll)
    has_role?(:owner, coll)
  end

  def add_uploads_collection
    self.uploads_collection = Collection.new(title: "Uploads", items_visible_by_default: false)
    create_uploads_collection_grant collection: uploads_collection
  end

  def plan
    owner ? owner.plan : SubscriptionPlanCached.organization
  end

  def owner_contact
    owner ? sprintf("%s <%s>", owner.name, owner.email) : '(nil)'
  end

  def set_amara_team(options={})
    options    = amara_team_defaults.merge(options)
    amara_team = find_or_create_amara_team(options)
    update_attribute(:amara_team, amara_team.slug)
  end

  def find_or_create_amara_team(options)
    amara_team = amara_client.teams.get(options[:slug]) rescue nil
    unless amara_team
      response = amara_client.teams.create(options)
      amara_team = response.object
    end
    amara_team
  end

  def amara_team_defaults
    {
      name: self.name,
      slug: self.name.parameterize,
      is_visible: false,
      membership_policy: Amara::TEAM_POLICIES[:invite]
    }
  end

  def amara_client
    Amara::Client.new(
    api_key:      amara_key || ENV['AMARA_KEY'],
    api_username: amara_username || ENV['AMARA_USERNAME'],
    endpoint:     "https://#{ENV['AMARA_HOST']}/api2/partners"
    )
  end

  def used_metered_storage
    @_used_metered_storage ||= billable_collections.map{|coll| coll.used_metered_storage}.inject(:+)
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= billable_collections.map{|coll| coll.used_unmetered_storage}.inject(:+)
  end

  def update_usage_report!
    update_attribute :used_metered_storage_cache, used_metered_storage
    update_attribute :used_unmetered_storage_cache, used_unmetered_storage
    update_attribute :transcript_usage_cache, transcript_usage_report
  end

  def self.get_org_ids_for_transcripts_since(since_dtim=nil)
    if since_dtim == nil
      since_dtim = DateTime.now - (1/24.0)  # an hour ago
    elsif since_dtim.is_a?(DateTime)
      # no op
    else
      since_dtim = DateTime.parse(since_dtim)
    end

    #puts "Checking transcripts modified since #{since_dtim}"

    transcripts_sql = "select t.audio_file_id from transcripts as t where t.updated_at >= '#{since_dtim.strftime('%Y-%m-%d %H:%M:%S')}'"
    audio_files_sql = "select a.item_id from audio_files as a where a.deleted_at is null and a.id in (#{transcripts_sql})"
    items_sql       = "select i.collection_id from items as i where i.deleted_at is null and i.id in (#{audio_files_sql})"
    colls_sql       = "select c.creator_id from collections as c where c.deleted_at is null and c.id in (#{items_sql})"
    grants_sql      = "select g.collector_id from collection_grants as g where g.collector_type='Organization' and g.collection_id in (#{colls_sql})"
    #puts grants_sql

    org_ids = []
    pgres = User.connection.execute(grants_sql)
    pgres.each_row do |row|
      org_ids << row.first
    end
    return org_ids
  end

end
