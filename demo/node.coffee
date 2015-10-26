{Client} = require "jsonrpc-node"
child  = require "child_process"

class Node extends Client

  send:(transaction, callback)->
    @call "sendrawtransaction", [transaction], callback

  subscribe:(callback)->
    @call "subscribe", [], (err)-> if err? then callback err
    @on "transaction", (transaction)-> callback null, transaction

  registerAddresses:(addresses, rescan, callback)->
    console.log "registering address: ",addresses
    if !callback?
      callback = rescan
      rescan = 0
    if !Array.isArray addresses then addresses = [addresses]
    @call "importaddress", addresses.concat(rescan), callback

  listTransactions:(limit, offset, callback)->
    @call "listtransactions", [limit, offset], callback

  getTransaction:(txid, callback)->
    @call "gettranscation", [txid], callback




module.exports = Node