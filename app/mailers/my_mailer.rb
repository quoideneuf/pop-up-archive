class MyMailer < ActionMailer::Base
  default to: ENV['MAILTO'], from: ENV['EMAIL_FROM'], template_path: ['base', 'mailer']

  def mailto(subject, body, to=nil)
    @body = body
    if to
      mail(subject: subject, to: to)
    else
      mail(subject: subject)
    end
  end

  def usage_alert(subject, body, to=nil)
    @body = body
    mail(subject: subject, to: to)
  end

end
