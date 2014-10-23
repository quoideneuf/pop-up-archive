class Organization < ActiveRecord::Base
  resourcify

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
    @_used_metered_storage ||= collections.map{|coll| coll.used_metered_storage}.inject(:+)
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= collections.map{|coll| coll.used_unmetered_storage}.inject(:+)
  end

  def update_usage_report!
    update_attribute :used_metered_hours_cache, used_metered_storage
    update_attribute :used_unmetered_hours_cache, used_unmetered_storage
    update_attribute :transcript_usage_cache, transcript_usage_report
  end

  def transcript_usage_report
    return {
      :basic_seconds => used_basic_transcripts[:seconds],
      :premium_seconds => used_premium_transcripts[:seconds],
      :basic_cost => used_basic_transcripts[:cost],
      :premium_cost => used_premium_transcripts[:cost],
    }
  end

  def total_transcripts_report(ttype=:basic)
    total_secs = 0
    total_cost = 0
    cost_where = '=0'

    # for now, we have only two types. might make sense
    # longer term to store the ttype on the transcriber record.
    case ttype
    when :basic
      cost_where = '=0'
    when :premium
      cost_where = '>0'
    end
    collections.each do |coll|
      coll.items.each do |item|
        item.audio_files.where('audio_files.duration is not null').each do|af|
          af.transcripts.unscoped.where("audio_file_id=#{af.id} and cost_per_min #{cost_where}").each do |tr|
            billable_secs = tr.billable_seconds(af)
            total_secs += billable_secs
            cpm = tr.cost_per_min
            mins = billable_secs.div(60)
            ttl = cpm * mins
            total_cost += ttl
          end
        end
      end
    end
    # cost_per_min is in 1000ths of a dollar, not 100ths (cents)
    # but we round to the nearest penny when we cache it in aggregate.
    # we make seconds and cost fixed-width so that sorting a string works
    # like sorting an integer.
    return { :seconds => "%010d" % total_secs, :cost => sprintf('%010.2f', total_cost.fdiv(1000)) }
  end

  def transcripts_billable_for_month_of(dtim=DateTime.now, transcriber_id)
    month_start = dtim.utc.beginning_of_month
    month_end = dtim.utc.end_of_month
    total_secs = 0
    total_cost = 0
    collections.each do |coll|
      coll.items.each do |item|
        item.audio_files.where('audio_files.duration is not null').where(created_at: month_start..month_end).each do |af|
          af.transcripts.unscoped.where("audio_file_id=? and transcriber_id=?", af.id, transcriber_id).each do|tr|
            billable_secs = tr.billable_seconds(af)
            total_secs += billable_secs
            cpm = tr.cost_per_min
            mins = billable_secs.div(60)
            ttl = cpm * mins
            total_cost += ttl
          end
        end
      end
    end
    return { :seconds => total_secs, :cost => total_cost.fdiv(1000) }
  end

  def used_basic_transcripts
    @_used_basic_transcripts ||= total_transcripts_report(:basic)
  end

  def used_premium_transcripts
    @_used_premium_transcripts ||= total_transcripts_report(:premium)
  end

  def get_total_seconds(ttype)
    ttype_s = ttype.to_s
    methname = 'used_' + ttype_s + '_transcripts'
    if transcript_usage_cache.has_key?(ttype_s+'_seconds')
      return transcript_usage_cache[ttype_s+'_seconds'].to_i
    else
      return send(methname)[:seconds].to_i
    end
  end

  def get_total_cost(ttype)
    ttype_s = ttype.to_s
    methname = 'used_' + ttype_s + '_transcripts'
    if transcript_usage_cache.has_key?(ttype_s+'_cost')
      return transcript_usage_cache[ttype_s+'_cost'].to_f
    else
      return send(methname)[:cost].to_f
    end
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
