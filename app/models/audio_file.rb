# encoding: utf-8
require "digest/md5"

class AudioFile < ActiveRecord::Base

  include PublicAsset
  include FileStorage
  acts_as_paranoid

  before_validation :set_metered
  before_save       :check_user_id

  belongs_to :item, :with_deleted => true
  belongs_to :user
  belongs_to :instance
  has_many :tasks, as: :owner
  has_many :transcripts, order: 'created_at desc'

  belongs_to :storage_configuration, class_name: "StorageConfiguration", foreign_key: :storage_id

  attr_accessible :storage_id

  mount_uploader :file, ::AudioFileUploader

  after_commit :process_file, on: :create
  after_commit :process_update_file, on: :update

  attr_accessor :should_trigger_fixer_copy

  default_scope order('"audio_files".created_at ASC')

  delegate :collection_title, to: :item

  TRANSCRIBE_RATE_PER_MINUTE = 2.00;  # TODO used?

  # returns object to which this audio_file should be accounted.
  # should be a User or Organization
  def billable_to
    collection.billable_to  # delegate, for now
  end

  def collection
    instance.try(:item).try(:collection) || item.try(:collection)
  end

  # shortcut for superadmin view
  def name
    self.filename
  end

  def get_token
    item.try(:token)
  end

  def get_storage
    item.try(:storage)
  end

  # verify that user_id is set, calling set_user_id if it is not.
  # called via before_save callback
  def check_user_id
    if self.user_id.nil?
      set_user_id
    end
  end

  def set_user_id(uid=nil)
    if uid.nil?
      # find a valid user
      if collection.creator_id
        self.user_id = collection.creator_id
      elsif collection.billable_to.is_a?(User)
        self.user_id = collection.billable_to.id
      elsif collection.billable_to.is_a?(Organization)
        self.user_id = collection.billable_to.users.first.id
      else
        raise "Failed to find a valid User to assign to AudioFile"
      end
    else
      self.user_id = uid
    end
  end
  
  def copy_media?
    item.collection.copy_media
  end

  def filename(version=nil)
    fn = if has_file?
      f = version ? file.send(version) : file
      File.basename(f.path)
    elsif !original_file_url.blank?
      f = URI.parse(original_file_url).path || ''
      x = File.extname(f)
      v = !version.blank? ? ".#{version}" : nil
      File.basename(f, x) + (v || x)
    end || ''
    fn
  end
  
  def remote_file_url=(url)
    self.original_file_url = url
    self.should_trigger_fixer_copy = !!url
  end

  def url(*args)
    if has_file? and !file.nil?
      file.try(:url, *args) 
    else 
      original_file_url
    end
  end

  def transcoded?
    !transcoded_at.nil?
  end

  def urls
    if transcoded?
      AudioFileUploader.version_formats.keys.collect{|v| url(v)}
    else
      [url]
    end
  end

  def update_file!(name, sid)
    sid = sid.to_i
    file_will_change!
    raw_write_attribute(:file, name)
    if (sid > 0) && (self.storage.id != sid)
      # see if the item is right
      if item.storage.id == sid
        self.storage_id = nil
        self.storage_configuration = nil
      else
        self.storage_id = sid
        self.storage_configuration = StorageConfiguration.find(sid)
      end
    end

    save!
  end

  def metered?
    metered.nil? ? is_metered? : super
  end

  def process_update_file
    # logger.debug "af #{id} call copy_to_item_storage"
    copy_to_item_storage

    transcribe_audio

    premium_transcribe_audio
  end

  def process_file
    # don't process file if no file to process yet (s3 upload)
    return if !has_file? && original_file_url.blank?

    analyze_audio

    copy_original

    transcribe_audio

    transcode_audio

  rescue Exception => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
  end

  def analyze_audio(force=false)
    result = nil
    if !force && task = tasks.analyze_audio.without_status(:failed).last
      logger.debug "analyze task #{task.id} already exists for audio_file #{self.id}"
    else
      result = Tasks::AnalyzeAudioTask.new(extras: { 'original' => process_file_url })
      self.tasks << result
    end
    result
  end

  # TODO used anymore?
  def amount_for_transcript
    (duration.to_i / 60.0).ceil * TRANSCRIBE_RATE_PER_MINUTE
  end

  def add_to_amara(user=self.user)
    options = {
      identifier: 'add_to_amara',
      extras: {
        'user_id' => user.try(:id)
      }
    }

    # if the user is in an org, and that org has an amara team defined, set it here
    if user.organization && user.organization.amara_team
      options[:extras]['amara_team'] = user.organization.amara_team
    end

    task = Tasks::AddToAmaraTask.new(options)
    self.tasks << task
    task
  end

  def premium_transcribe_audio(user=self.user)
    # only start this if transcode is complete
    return unless transcoded_at
    return unless (user.plan.has_premium_transcripts? || item.is_premium?)
    start_premium_transcribe_job(user, 'ts_paid')
  end

  def transcribe_audio(user=self.user)
    # don't bother if this is premium plan
    return if (user && user.plan.has_premium_transcripts?)
    # or if parent Item was created with premium-on-demand
    return if item.is_premium?
 
    # always do the first 2 minutes
    start_transcribe_job(user, 'ts_start', {start_only: true})

    if (storage.at_internet_archive? || (user && (user.plan != SubscriptionPlanCached.community)))
      start_transcribe_job(user, 'ts_all')
    end
  end

  def start_premium_transcribe_job(user, identifier, options={})
    return if (duration.to_i <= 0)

    if task = has_premium_transcribe_task?
      logger.warn "speechmatics transcribe task #{task.id} #{identifier} already exists for audio file #{self.id}"
      task
    else
      extras = { 'original' => process_file_url, 'user_id' => user.try(:id) }.merge(options)
      task = Tasks::SpeechmaticsTranscribeTask.new(identifier: identifier, extras: extras)
      self.tasks << task
      task
    end
  end

  def start_transcribe_job(user, identifier, options={})
    extras = { 'original' => process_file_url, 'user_id' => user.try(:id) }.merge(options)

    if task = tasks.transcribe.without_status(:failed).where(identifier: identifier).last
      logger.debug "transcribe task #{identifier} #{task.id} already exists for audio file #{self.id}"
    else
      self.tasks << Tasks::TranscribeTask.new( identifier: identifier, extras: extras )
    end
  end
  
  def order_transcript(user=self.user)
    raise 'cannot create transcript when duration is 0' if (duration.to_i <= 0)
    task = Tasks::OrderTranscriptTask.new(
      identifier: 'order_transcript',
      extras: { 'user_id' => user.id, 'amount' => amount_for_transcript }
    )
    self.tasks << task
    task
  end  

  def transcode_audio(user=self.user)
    return if transcoded_at #skip if audio already has a transcoded at value

    #detect IA file derivatives if audio is stored at IA
    if storage.automatic_transcode?
      start_detect_derivative_job
    else
      AudioFileUploader.version_formats.each do |label, info|
        next if (label == filename_extension) # skip this version if that is already the file's format
        #log and skip if transcode task already exists
        if task = tasks.transcode.without_status(:failed).where(identifier: "#{label}_transcode").last
          logger.debug "transcode task #{identifier} #{task.id} already exists for audio file #{self.id}"
          task
        else
          self.tasks << Tasks::TranscodeTask.new(
            identifier: "#{label}_transcode",
            extras: info
          )
        end
      end
    end
  end

  def start_detect_derivative_job
    if !has_file?
      logger.debug "detect_derivatives audio_file #{self.id} not yet saved to archive.org"
      return
    end

    task = tasks.detect_derivatives.without_status(:failed).where(identifier: 'detect_derivatives').last
    if task
      logger.debug "detect_derivatives task #{task.id} already exists for audio_file #{self.id}"
      return
    end

    task = Tasks::DetectDerivativesTask.new(identifier: 'detect_derivatives')
    task.urls = detect_urls
    self.tasks << task
  end

  def detect_urls
    AudioFileUploader.version_formats.keys.inject({}){|h, k| h[k] = { url: file.send(k).url, detected_at: nil }; h}
  end

  def is_transcode_complete?
    return true if storage.automatic_transcode?

    complete = true
    AudioFileUploader.version_formats.each do |label, info|
      next if (label == filename_extension) # skip this version if that is alreay the file's format
      task = tasks.transcode.with_status('complete').where(identifier: "#{label}_transcode").last
      complete = !!task
      break if !complete
    end
    complete
  end

  def check_transcode_complete
    update_attribute(:transcoded_at, DateTime.now) if is_transcode_complete?
  end

  def transcript_array
    timed_transcript_array.present? ? timed_transcript_array : (@_tta ||= JSON.parse(transcript)) rescue []
  end

  def transcript_text
    txt = timed_transcript_text
    txt = JSON.parse(transcript).collect{|i| i['text']}.join("\n") if (txt.blank? && !transcript.blank?)
    txt || ''
  end

  def timed_transcript_text(language='en-US')
    (timed_transcript(language).try(:timed_texts) || []).collect{|tt| tt.text}.join("\n")
  end

  def timed_transcript_array(language='en-US')
    @_timed_transcript_arrays ||= {}
    @_timed_transcript_arrays[language] ||= (timed_transcript(language).try(:timed_texts) || []).collect{|tt| tt.as_json(only: [:id, :start_time, :end_time, :text, :speaker_id])}
  end

  def timed_transcript(language='en-US')
    transcripts.detect{|t| t.language == language }
  end

  def analyze_transcript
    self.tasks << Tasks::AnalyzeTask.new(extras: { 'original' => transcript_text_url })
  end

  def transcript_text_url
    Rails.application.routes.url_helpers.api_item_audio_file_transcript_text_url(item_id, id)
  end

  def transcripts_alone
    self.transcripts.unscoped.where(:audio_file_id => self.id)
  end

  def is_premium?
    # call unscoped w/explicit 'where' to avoid loading timed texts too.
    self.transcripts.unscoped.where(:audio_file_id => self.id).any?{|t| t.is_premium?}
  end

  def has_premium_transcribe_task?
    self.tasks.select{|task| task.type == 'Tasks::SpeechmaticsTranscribeTask' && task.status != "failed"}.first
  end

  def has_premium_transcribe_task_in_progress?
    self.tasks.where('type in (?)', ['Tasks::SpeechmaticsTranscribeTask']).\
               where('status not in (?)', ['complete', 'cancelled']).count > 0 \
               ? true : false
  end

  def transcript_type
    (self.is_premium? or self.item.is_premium?) ? "Premium" : "Basic"
  end

  def premium_wholesale_cost(transcriber=Transcriber.premium)
    transcriber.wholesale_cost(self.duration)
  end

  def premium_retail_cost(transcriber=Transcriber.premium)
    transcriber.retail_cost(self.duration)
  end

  def order_premium_transcript(cur_user)
    # TODO create named exception classes for these errors
    if !transcoded_at and format != "audio/mpeg"
      raise "Cannot order premium transcript for audio that has not been transcoded"
    end
    if !cur_user.active_credit_card
      raise "Cannot order premium transcript without an active credit card"
    end
    start_premium_transcribe_job(cur_user, 'ts_paid', { ondemand: true })
  end

  def self.all_public_duration
    self.connection.execute("select sum(af.duration) as dursum from items as i, audio_files as af where i.is_public=true and af.item_id=i.id").first.first[1]
  end

  def self.all_private_duration
    self.connection.execute("select sum(af.duration) as dursum from items as i, audio_files as af where i.is_public=false and af.item_id=i.id").first.first[1]
  end

  private

  def set_metered
    self.metered = is_metered?
    true
  end

  def is_metered?
    storage == StorageConfiguration.popup_storage
  end
end
