class MyMailer < ActionMailer::Base
  default to: ENV['MAILTO'], from: ENV['EMAIL_FROM'], template_path: ['base', 'mailer']

  def mailto(subject, body)
    @body = body
    mail(subject: subject)
  end

end
