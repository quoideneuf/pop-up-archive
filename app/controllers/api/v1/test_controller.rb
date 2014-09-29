class Api::V1::TestController < Api::V1::BaseController
  def croak 
    raise "This is a fatal error"
  end

end
