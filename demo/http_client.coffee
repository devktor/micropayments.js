qs = require "qs"
http = require "http"

class HTTPClient
  constructor:(@host, @port)->

  post:(path, data, callback)->
    options =
      host: @host
      port: @port
      path: path,
      method: 'POST'
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Host': @host
    query = qs.stringify data
    options.headers['Content-Length'] = query.length
    request = http.request options, (response)->
      message=''
      response.on "data", (data)->
        message+=data
      response.on "end",()->
        console.log "message=",message
        if message.length
          try
            data = JSON.parse message
            callback null, data
          catch e
            callback e
        else
          callback null
    request.on "error", (err)-> callback err

    request.write query




module.exports = HTTPClient