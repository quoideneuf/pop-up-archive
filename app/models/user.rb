require 'customer'

class User < ActiveRecord::Base
  rolify
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :provider, :uid, :name

  belongs_to :organization
  belongs_to :subscription_plan

  after_validation :customer #ensure that a stripe customer has been created
  after_destroy :delete_customer
  after_commit :add_default_collection, on: :create

  has_many :collection_grants, as: :collector
  has_one  :uploads_collection_grant, class_name: 'CollectionGrant', as: :collector, conditions: {uploads_collection: true}, autosave: true

  has_one  :uploads_collection, through: :uploads_collection_grant, source: :collection
  has_many :collections, through: :collection_grants, include: :default_storage
  has_many :items, through: :collections
  has_many :audio_files, through: :items
  has_many :csv_imports
  has_many :oauth_applications, class_name: 'Doorkeeper::Application', as: :owner

  has_many :monthly_usages, as: :entity

  has_many :owned_organizations, class_name: 'Organization', foreign_key: 'owner_id'

  validates_presence_of :name, if: :name_required?
  validates_presence_of :uploads_collection

  OVERAGE_CALC = 'coalesce(used_metered_storage_cache - pop_up_hours_cache * 3600, 0)'

  scope :over_limits, -> { select("users.*, #{OVERAGE_CALC} as overage").where("#{OVERAGE_CALC} > 0").order('overage DESC') }

  delegate :name, :id, :amount, to: :plan, prefix: true

  def self.find_for_oauth(auth, signed_in_resource=nil)
    where(provider: auth.provider, uid: auth.uid).first ||
    create{|user| user.apply_oauth(auth)}
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.oauth_data"]
        user.provider = data['provider']
        user.uid      = data['uid']
        user.email    = data["email"] if user.email.blank?
        user.name     = data["name"] if user.name.blank?
        user.valid?   if data[:should_validate]
      end
    end
  end

  def apply_oauth(auth)
    self.provider = auth.provider
    self.uid      = auth.uid
    self.name     = auth.info.name
    self.email    = auth.info.email
  end

  def password_required?
    # logger.debug "password_required? checked on #{self.inspect}\n"
    !provider.present? && !@skip_password && super
  end

  def name_required?
    # logger.debug "name_required? checked on #{self.inspect}\n"
    !provider.present? && !@skip_password && !name.present?
  end

  def searchable_collection_ids
    collection_ids - [uploads_collection.id]
  end

  def collections
    organization ? organization.collections : super
  end

  def collection_ids
    organization ? organization.collection_ids : super
  end

  def uploads_collection
    organization.try(:uploads_collection) || uploads_collection_grant.collection || add_uploads_collection
  end

  def in_organization?
    !!organization_id
  end

  # everyone is considered an admin on their own, role varies for those in orgs
  def role
    return :admin unless organization
    has_role?(:admin, organization) ? :admin : :member
  end

  def super_admin?
    has_role?(:super_admin)
  end

  def update_card!(card_token)
    cus = customer.stripe_customer
    cus.card = card_token
    cus.save
    invalidate_cache
  end

  def subscribe!(plan, offer = nil)
    cus = customer.stripe_customer
    if (offer == 'prx')
      cus.update_subscription(plan: plan.id, trial_end: 90.days.from_now.to_i)
    else
      cus.update_subscription(plan: plan.id, coupon: offer)
    end

    # must do this manually after update_subscription has successfully completed
    # so that our local caches are in sync.
    sp = SubscriptionPlan.find_by_stripe_plan_id(plan.id)
    self.update(:subscription_plan_id => sp.id)

    invalidate_cache
  end

  def add_invoice_item!(invoice_item)
    cus = customer.stripe_customer
    cus.add_invoice_item(invoice_item)
  end

  def plan
    if organization && (organization.owner_id != id)
      return organization.plan
    elsif subscription_plan_id.present?
      return subscription_plan.as_cached
    else
      return customer.plan
    end
  end

  def entity
    organization || self
  end

  def usage_for(use, now=DateTime.now)
    entity.monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).sum(:value)
  end

  def update_usage_for(use, value, now=DateTime.now)
    entity.monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).first_or_initialize.update_attributes!(value: value)
  end

  def plan_json
    {
      name: plan.name,
      id: plan.id,
      amount: plan.amount,
      pop_up_hours: plan.hours,
      trial: customer.trial,  # TODO cache this better to avoid needing to call customer() at all.
      interval: plan.interval
    }
  end

  def customer
    return @_customer if !@_customer.nil?
    begin
      cache_ttl = Rails.application.config.stripe_cache
    rescue
      cache_ttl = 5.minutes
    end
    if customer_id.present?
      Rails.cache.fetch([:customer, :individual, customer_id], expires_in: cache_ttl) do
        cus = nil
        begin
          cus = Customer.new(Stripe::Customer.retrieve(customer_id))
          # update our local cache to point at the current plan
          sp = SubscriptionPlan.find_by_stripe_plan_id(cus.plan.id)
          update_attribute :subscription_plan_id, sp.id if persisted?
        rescue Stripe::InvalidRequestError => err
          #puts "Error: #{err.message} #{err.http_status}"
          if err.http_status == 404 and err.message.match(/object exists in live mode, but a test mode key/)
            Rails.logger.warn("Stripe returned 404 for #{customer_id} [user #{self.id}] running in Stripe test mode")
            #Rails.logger.warn(Thread.current.backtrace.join("\n"))
            # use generic Customer object here so dev/stage still work with prod snapshots
            cus = Customer.generic_community
          else
            raise err
          end
        rescue => err
          raise "Caught Stripe error #{err}"
        end
        @_customer = cus
        return cus
      end
    else
      Customer.new(Stripe::Customer.create(email: email, description: name)).tap do |cus|
        self.customer_id = cus.id
        update_attribute :customer_id, cus.id if persisted?
        Rails.cache.write([:customer, :individual, cus.id], cus, expires_in: cache_ttl)
        sp = SubscriptionPlan.find_by_stripe_plan_id(cus.plan.id)
        update_attribute :subscription_plan_id, sp.id if persisted?
        @_customer = cus
      end
    end
  end

  def pop_up_hours
    plan.hours
  end

  def used_metered_storage
    @_used_metered_storage ||= audio_files.where(metered: true).sum(:duration)
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= audio_files.where(metered: false).sum(:duration)
  end

  def used_basic_transcripts
    @_used_basic_transcripts ||= total_transcripts_report(:basic)
  end

  def used_premium_transcripts
    @_used_premium_transcripts ||= total_transcripts_report(:premium)
  end

  def active_credit_card_json
    active_credit_card.as_json.try(:slice, *%w(last4 type exp_month exp_year))
  end

  def active_credit_card
    customer.card
  end

  def update_usage_report!
    update_attribute :used_metered_storage_cache, used_metered_storage
    update_attribute :pop_up_hours_cache, pop_up_hours
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
    audio_files.each do|af|
      if af.transcripts.where("cost_per_min #{cost_where}").count > 0
        total_secs += af.duration
        af.transcripts.unscoped.where("audio_file_id=#{af.id} and cost_per_min #{cost_where}").each do |tr|
          cpm = tr.cost_per_min
          mins = af.duration.div(60)
          ttl = cpm * mins
          total_cost += ttl
        end
      end
    end
    # cost_per_min is in 1000ths of a dollar, not 100ths (cents)
    # but we round to the nearest penny when we cache it in aggregate.
    return { :seconds => total_secs, :cost => sprintf('%.2f', total_cost.fdiv(1000)) }
  end

  private

  def delete_customer
    customer.stripe_customer.delete
    invalidate_cache
  end

  def add_uploads_collection
    uploads_collection_grant.collection = Collection.new(title: 'My Uploads', creator: self, items_visible_by_default: false)
    if persisted?
      uploads_collection_grant.collection.save
      if grant = collection_grants.where(collection_id: uploads_collection_grant.collection.id).first
        self.uploads_collection_grant = grant
        grant.uploads_collection = true
      end
      uploads_collection_grant.save
    end
    uploads_collection_grant.collection
  end

  def uploads_collection_grant
    super or self.uploads_collection_grant = CollectionGrant.new(collector: self, uploads_collection: true)
  end

  def customer_cache_id
    [:customer, :individual, customer_id]
  end

  def invalidate_cache
    Rails.cache.delete(customer_cache_id)
  end

  def add_default_collection
    title = "#{name}'s Collection"
    collection = Collection.new(title: title, creator: self, items_visible_by_default: false)
    collection.save!
    collection
  end

end
