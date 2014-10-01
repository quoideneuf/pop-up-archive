class Api::BaseController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  rescue_from RuntimeError, :with => :runtime_error
  rescue_from ActionView::MissingTemplate, :with => :template_error
  rescue_from Stripe::InvalidRequestError, :with => :upstream_error

  def not_found
    respond_to do |format|
      # TODO render app 404 rather than generic 
      format.html { render :file => File.join(Rails.root, 'public', '404'), :formats => [:html], :status => :not_found }

      format.json { render :text => { :error => "not found", :status => 404 }.to_json, :status => :not_found }
    end

  end

  def runtime_error(exception)
    logger.error(exception)
    respond_to do |format|
      format.html {
        render :file => File.join(Rails.root, 'public', '500'), 
        :formats => [:html],
        :locals => { :exception => exception },
        :status => 500
      }
      format.json {
        render :text => { :error => "Internal server error", :status => 500 }.to_json,
        :status => 500
      }
    end
  end

  def template_error(exception)
    logger.error(exception)
    respond_to do |format|
      format.html {
        render :file => File.join(Rails.root, 'public', '500'),
        :formats => [:html],
        :locals => { :exception => exception },
        :status => 507
      }   
      format.json {
        render :text => { :error => "Cannot present response", :status => 507 }.to_json,
        :status => 507
      }   
    end 
  end

  def upstream_error(exception)
    logger.error(exception)
    respond_to do |format|
      format.html {
        render :file => File.join(Rails.root, 'public', '500'),
        :formats => [:html],
        :locals => { :exception => exception },
        :status => 502
      }   
      format.json {
        render :text => { :error => "Upstream server error", :status => 502 }.to_json,
        :status => 502
      }   
    end 
  end

end
