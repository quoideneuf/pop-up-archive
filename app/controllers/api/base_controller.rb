class Api::BaseController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  rescue_from RuntimeError, :with => :runtime_error
  rescue_from ActionView::MissingTemplate, :with => :template_error

  def not_found
    respond_to do |format|
      format.html { render :file => File.join(Rails.root, 'public', '404.html'), :status => :not_found }
      format.json { render :text => { :error => "not found", :status => 404 }.to_json, :status => :not_found }
    end

  end

  def runtime_error(exception)
    logger.error(exception)
    respond_to do |format|
      format.html {
        render :file => File.join(Rails.root, 'public', '500.html'),
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
        render :file => File.join(Rails.root, 'public', '500.html'),
        :locals => { :exception => exception },
        :status => 507
      }   
      format.json {
        render :text => { :error => "Cannot present response", :status => 500 }.to_json,
        :status => 507
      }   
    end 
  end
end
