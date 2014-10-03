module Api::BaseHelper
  def infer_model_name(controller)
    controller.camelize.demodulize.underscore.singularize.intern
  end

  def inferred_model(controller)
    send(infer_model_name(controller))
  end

  def format_time(seconds)
    Time.at(seconds).getgm.strftime('%H:%M:%S')
  end

  def total_hours_on_pua
    hours = Rails.cache.fetch(:pua_total_hours_on_pua, expires_in: 60.minutes) do
      u = User.all
      total_time = u.map {|user| [user.used_unmetered_storage, user.used_metered_storage] }.flatten.sum 
      hours = time_definition(total_time)
    end
    return hours
  end

  def total_time_in_hours
    hours = Rails.cache.fetch(:pua_total_time_in_hours, expires_in: 60.minutes) do
      u = User.all
      total_time = u.map {|user| [user.used_unmetered_storage, user.used_metered_storage] }.flatten.sum
      hours = (total_time / 3600).to_s + "hrs"
    end
    return hours
  end        

  def time_definition(total_time)
    mm, ss = total_time.divmod(60)            
    hh, mm = mm.divmod(60)           
    dd, hh = hh.divmod(24)         
    time = "%dd: %dh: %dm: %ds" % [dd, hh, mm, ss]
    return time
  end  	
end
