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

  attr_accessible :storage_id, :remote_file_url

  mount_uploader :file, ::AudioFileUploader

  after_commit :process_file, on: :create
  after_commit :process_update_file, on: :update

  attr_accessor :should_trigger_fixer_copy

  default_scope order('"audio_files".created_at ASC')

  delegate :collection_title, to: :item

  TRANSCRIBE_RATE_PER_MINUTE = 2.00;  # TODO used?

  # status messages
  UNKNOWN_STATE               = 'Unknown'
  TRANSCRIPT_PREVIEW_COMPLETE = 'Transcript preview complete'
  TRANSCRIPT_SAMPLE_COMPLETE  = 'Transcript sample complete'
  TRANSCRIPT_BASIC_COMPLETE   = 'Basic transcript complete'
  TRANSCRIPT_PREMIUM_COMPLETE = 'Premium transcript complete'
  UPLOADING_INPROCESS         = 'Uploading'
  UPLOAD_FAILED               = 'Upload failed'
  COPYING_INPROCESS           = 'Copying'
  TRANSCODING_INPROCESS       = 'Transcoding'
  TRANSCRIBE_INPROCESS        = 'Transcribing'
  STUCK                       = 'Processing'

  # returns object to which this audio_file should be accounted.
  # should be a User or Organization
  def billable_to
    collection.billable_to  # delegate, for now
  end

  # if user_id not defined, prefer billable_to
  def user
    if user_id
      super
    else
      billable_to.owner  # always a User
    end
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

  def is_mp3?
    return true if self.format == "audio/mpeg"
    return true if self.filename_extension == "mp3"
    return false
  end
  
  def remote_file_url=(url)
    self.original_file_url = url
    self.should_trigger_fixer_copy = !!url
  end

  def player_url
    if transcoded?
      permanent_public_url({:extension => 'mp3'})
    else
      permanent_public_url
    end
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
      AudioFileUploader.version_formats.keys.collect{|v| permanent_public_url({:extension => v})}
    else
      [permanent_public_url]
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
    
    transcode_audio

    transcribe_audio

  rescue Exception => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
  end

  # make sure all the relevant tasks have been created.
  # note that each method called is responsible for checking whether it should be created.
  def check_tasks
    analyze_audio
    copy_original
    transcode_audio
    copy_to_item_storage
    transcribe_audio
    premium_transcribe_audio
    if !needs_transcript?
      analyze_transcript
    end
  end
 
  def analyze_audio(force=false)
    #for IA only start if transcode complete
    return if !self.transcoded? and storage.at_internet_archive?
    result = nil
    if !force
      if task = (tasks.analyze_audio.valid.pop || tasks.select { |t| t.type == "Tasks::AnalyzeAudioTask" && !t.cancelled? }.pop)
        logger.warn "AudioFile #{self.id} already has analyze_audio task #{task.id}"
        return nil
      end
    end
    result = Tasks::AnalyzeAudioTask.new(extras: { 'original' => process_file_url })
    self.tasks << result
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

    if task = (tasks.add_to_amara.valid.pop || tasks.select { |t| t.type == "Tasks::AddToAmaraTask" && !t.cancelled? }.pop)
      logger.warn "AddToAmaraTask already exists #{task.id} for audio_file #{self.id}"
    else
      task = Tasks::AddToAmaraTask.new(options)
      self.tasks << task
    end
    task
  end

  def premium_transcribe_audio(user=self.user)
    # only start this if transcode is complete
    return unless transcoded_at or self.is_mp3?
    return unless ((user && user.plan.has_premium_transcripts?) || item.is_premium?)

    # do not re-create if we have one already
    return if has_premium_transcript?

    opts = {}
    # if the user is on a basic plan, but the item is flagged premium,
    # then the user must have requested a premium treatment at upload time.
    if !user.plan.has_premium_transcripts? and item.is_premium?
      opts['ondemand'] = true
    end
    start_premium_transcribe_job(user, 'ts_paid', opts)
  end

  def transcribe_audio(user=self.user)
    #for IA only start if transcode complete
    return if !self.transcoded? and storage.at_internet_archive?
    # only start if transcode is complete
    return unless self.transcoded? or self.is_mp3?
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

    if task = (tasks.speechmatics_transcribe.valid.pop || tasks.select { |t| t.type == "Tasks::SpeechmaticsTranscribeTask" && !t.cancelled? }.pop)
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

    if task = (tasks.transcribe.valid.where(identifier: identifier).pop || tasks.select { |t| t.type == "Tasks::TranscribeTask" && t.identifier == identifier && !t.cancelled? }.pop)
      logger.warn "transcribe task #{identifier} #{task.id} already exists for audio file #{self.id}"
    else
      self.tasks << Tasks::TranscribeTask.new( identifier: identifier, extras: extras )
    end
  end
  
  def order_transcript(user=self.user)
    raise 'cannot create transcript when duration is 0' if (duration.to_i <= 0)
    if task = (tasks.order_transcript.valid.where(identifier: 'order_transcript').pop || tasks.select { |t| t.type == "Tasks::OrderTranscriptTask" && t.identifier == 'order_transcript' && !t.cancelled? }.pop)
      logger.warn "order_transcript task #{task.id} already exists for audio file #{self.id}"
    else
      task = Tasks::OrderTranscriptTask.new(
        identifier: 'order_transcript',
        extras: { 'user_id' => user.id, 'amount' => amount_for_transcript }
      )
      self.tasks << task
    end
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
        if task = (tasks.transcode.valid.where(identifier: "#{label}_transcode").pop || tasks.select { |t| t.type == "Tasks::TranscodeTask" && t.identifier == "#{label}_transcode" && !t.cancelled? }.pop)
          logger.warn "transcode task #{identifier} #{task.id} already exists for audio file #{self.id}"
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

    if task = (tasks.detect_derivatives.valid.where(identifier: 'detect_derivatives').pop || tasks.select { |t| t.type == "Tasks::DetectDerivativesTask" && t.identifier != 'detect_derivatives' && !t.cancelled? }.pop)
      logger.warn "detect_derivatives task #{task.id} already exists for audio_file #{self.id}"
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
    return unless transcripts_alone.count > 0
    if task = (tasks.analyze.valid.pop || tasks.select { |t| t.type == "Tasks::AnalyzeTask" && !t.cancelled? }.pop)
      logger.warn "AudioFile #{self.id} already has analyze task #{task.id}"
      return
    end
    self.tasks << Tasks::AnalyzeTask.new(extras: { 'original' => transcript_text_url })
  end

  def transcript_text_url
    Rails.application.routes.url_helpers.api_item_audio_file_transcript_text_url(item_id, id)
  end

  # avoid default scope because we do not want timed_texts
  def transcripts_alone
    self.transcripts.unscoped.where(:audio_file_id => self.id)
  end

  def stuck?
    return true if self.tasks.any?{|t| t.stuck?}
    return true if self.needs_transcript?
    return false
  end

  # kick off an async worker which will call the recover! method.
  def recover_async
    return if !stuck?
    RecoverAudioFileWorker.perform_async(id) unless Rails.env.test?
  end

  def recover!
    self.tasks.each do |task|
      if task.stuck?
        task.recover!
      end
    end
  end

  def has_preview?
    # short audio, any transcript
    if self.duration and self.duration < 120 and self.transcripts_alone.count > 0
      return true
    end
    self.transcripts_alone.where(:end_time => 120, :start_time => 0).count > 0
  end

  def has_basic_transcript?
    self.transcripts_alone.any?{|t| t.is_basic?}
  end

  # symmetry only
  def has_premium_transcript?
    is_premium?
  end

  def is_premium?
    self.transcripts_alone.any?{|t| t.is_premium?}
  end

  # returns true if audio still requires a basic or premium transcript. preview is excluded.
  def needs_transcript?
    # if user has plan needing more than preview, 
    # and there are no transcripts yet created, 
    # and no tasks in process.
    if transcripts_alone.count == 0 and !has_basic_transcribe_task_in_progress? and !has_premium_transcribe_task_in_progress?
      return true
    end

    # compare plan expectations with reality
    if user && user.plan
      # expect 2-minute preview only
      if user.plan == SubscriptionPlanCached.community
        return false
      end
      # expect premium transcript
      if user.plan.has_premium_transcripts?
        if has_premium_transcript?
          return false
        elsif has_premium_transcribe_task_in_progress?
          return false
        else
          return true
        end
      end
      # expect basic transcript
      if user.plan != SubscriptionPlanCached.community
        if has_basic_transcript?
          return false
        elsif has_basic_transcribe_task_in_progress?
          return false
        else
          return true
        end
      end
    end

    return false
  end

  def unfinished_tasks
    self.tasks.unfinished
  end

  def has_basic_transcribe_task_in_progress?
    self.unfinished_tasks.transcribe.count > 0
  end

  def has_premium_transcribe_task_in_progress?
    self.unfinished_tasks.speechmatics_transcribe.count > 0
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
    if !transcoded_at and !self.is_mp3?
      raise "Cannot order premium transcript for audio that has not been transcoded"
    end
    if !cur_user.super_admin? && !cur_user.active_credit_card
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

  def is_uploaded?
    return true if original_file_url
    if self.tasks.upload.count == 0 && self.tasks.count > 0
      return true
    elsif self.tasks.upload.with_status(Task::COMPLETE).count > 0
      return true
    else
      return false
    end
  end

  # if there are non-zero upload tasks and all of them are cancelled, it's a Fail.
  # Do *NOT* nudge the task if older 1 hour; let the nudger do that.
  def has_failed_upload?
    num_uploads           = tasks.upload.count
    num_complete_uploads  = tasks.upload.with_status(Task::COMPLETE).count
    num_valid_uploads     = tasks.upload.valid.count  # i.e. not-cancelled
    num_cancelled_uploads = num_uploads - num_valid_uploads

    # easy cases first
    return false if num_uploads == 0
    return false if num_complete_uploads == num_uploads
    return false if num_complete_uploads > 1
    return true if num_cancelled_uploads == num_uploads

    return false  # conservative default
  end

  # if audio should be copied, returns whether it has.
  # if audio should not be copied, always returns true.
  def is_copied?
    return true unless copy_media?
    if self.tasks.copy.count > 0
      return self.tasks.copy.with_status(Task::COMPLETE).count > 0
    else
      return false
    end
  end

  def current_status
    # the order of progression, regardless of what order the tasks actually complete.
    # upload (or copy)
    # analyze audio
    # copy
    # transcode
    # transcribe
    # * preview
    # * basic
    # * premium
    # analyze
    #
    # because all these tasks are async, we just evaluate the current state
    # in a fail-forward progression, assuming that all previous conditions are true
    # if the current condition is true.
    status = UNKNOWN_STATE
    if self.tasks.upload.count > 0 && !self.is_uploaded? && !self.is_copied?
      # abort status determination early if upload has not finished.
      if self.has_failed_upload?
        return UPLOAD_FAILED
      else 
        return UPLOADING_INPROCESS
      end
    end

    # if we have zero tasks and the file is older than generic work window, consider it DOA.
    if self.tasks.count == 0 && updated_at < Task.work_window
      return UPLOAD_FAILED
    end

    if self.tasks.copy.count > 0 && !self.is_copied?
      status = COPYING_INPROCESS
    end
    if self.is_copied? and self.is_uploaded?
      status = TRANSCODING_INPROCESS
    end
    if (self.transcoded? or self.is_mp3?) and (self.has_basic_transcribe_task_in_progress? or self.has_premium_transcribe_task_in_progress?)
      status = TRANSCRIBE_INPROCESS
    end

    # check for "stuck" before any transcript checks,
    # so that subsequent transcript checks can override.
    # this is because even though a lower-level task may be 'stuck'
    # it is possible the chain has sufficiently recovered enough
    # to produce a transcript, which is the end goal in any case.
    if self.stuck?
      status = STUCK
    end

    # now transcript checks
    if self.has_preview?
      status = TRANSCRIPT_PREVIEW_COMPLETE
    end
    # if the 2-min is done, and we do not expect any more, call it a "sample"
    if self.has_preview? and !self.needs_transcript? and !has_basic_transcribe_task_in_progress?
      status = TRANSCRIPT_SAMPLE_COMPLETE
    end
    if self.has_basic_transcript?
      status = TRANSCRIPT_BASIC_COMPLETE
    end
    if self.has_premium_transcript?
      status = TRANSCRIPT_PREMIUM_COMPLETE
    end

    # TODO do we care about communicating the analyze status?

    status
  end

  def is_finished?
    status = current_status
    if status == TRANSCRIPT_SAMPLE_COMPLETE
      return true
    elsif status == TRANSCRIPT_BASIC_COMPLETE
      return true
    elsif status == TRANSCRIPT_PREMIUM_COMPLETE
      return true
    else
      return false
    end
  end

  def best_transcript
    if self.has_premium_transcript?
      self.transcripts.each do |t|
        if t.is_premium?
          return t
        end
      end
    elsif self.has_basic_transcript?
      self.transcripts.each do |t|
        if t.is_basic?
          return t
        end
      end
    elsif self.has_preview?
      self.transcripts.first
    else
      self.transcripts.first # TODO will this ever yield anything?
    end
  end

  def duration_hms
    Api::BaseHelper::format_time(duration||0)
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
