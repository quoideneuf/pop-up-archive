object false

cur_url = request.domain
if request.port != 80
  cur_url += ':' + request.port.to_s
end
node(:version) { '1.0' }
node(:url) { "https://#{cur_url}/api/" }
