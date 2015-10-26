ChannelServer = require "../channel_server"
{ChannelServerContext, ChannelServerContextFactory} = require "../channel_server_context"
{Transaction, Address, ECKey, ECPubKey} = require "bitcoinjs-lib"

class Controller
  constructor:(@network, @node, @db)->
    @node.subscribe (err, data)=>
      if err? or not data? or not data.hex?
        console.log "notification error: ",err
      else
        @processDeposit data.hex

  processDeposit:(hex)->
    transaction = Transaction.fromHex hex
    outputs = []
    for output in transaction.outs
      outputs.push Address.fromOutputScript(output.script, @network).toString()
    @db.collection("channel").findOne {id:{$in:outputs}}, (err, contextData)=>
      if err? or not contextData?
        console.log "contract not found : ",err
      else
        context = new ChannelServerContext @network
        context.fromJSON contextData
        server = new ChannelServer context
        if server.initContract hex
          @db.collection("channel").update {id:contextData.id}, {$set:context.toJSON()}, (err)->
            if err?
              console.log "failed to update context #{contextData.id} : ",err
            else
              console.log "channel #{contextData.id} started"
    undefined


  getStatus:(req, res)->
    @execute req, res, false, (server)->
      res.send {status: if !server.context.active then "closed" else if server.context.contractID? then "open" else "pending"}

  requestChannel:(req, res)->
    console.log "req: ",req.body
    if !req.body.pubkey?
      res.sendStatus 400
    else
      context = ChannelServerContextFactory.Create @network, ECPubKey.fromHex req.body.pubkey
#      context = ChannelServerContextFactory.CreateFromKey @network, ECKey.fromWIF("KxPT8wdUkxiuenxKcWh8V79pGxRQumQFtYEbYWcw1gRf8wNLm5m3"), ECPubKey.fromHex req.body.pubkey
      channelData = context.toJSON()
      channelData.id = context.getContractAddress().toString()
      channelData.active = false
      @db.collection("channel").insert channelData, (err)=>
        if err?
          res.sendStatus 500
        else
          @node.registerAddresses channelData.id, (err)=>
            if err?
              @db.collection("channel").remove {id:channelData.id}, (err)-> if err? then throw err
              res.sendStatus 500
            else
              res.send pubkey:context.getServerPubKey()

  closeChannel:(req, res)->
    @execute req, res, false, (server)=>
      if server.context.paidAmount
        tx = server.getCloseTransaction()
        if !tx
          res.sendStatus 400
        else
          console.log "transaction :",tx.toHex()
          @node.send tx.toHex(), (err)=>
            if err?
              console.log "failed to send transaction: ",err
              active = true
            else
              active = false
            @db.collection("channel").update {id:server.context.id}, {$set:{active:active}}, (err)->
              if err?
                console.log "failed to update context ",err
                res.sendStatus 500
              else
                if active
                  console.log "contract not active"
                  res.sendStatus 500
                else
                  console.log "channel #{server.context.id} closed, total paid: ",server.context.paidAmount
                  console.log "payment tx: ",tx.getId()
                  res.send {totalPaid:server.context.paidAmount, paymentID:tx.getId()}


  signRefund:(req, res)->
    @execute req, res, true, (server)->
      refund = server.signRefund req.body.tx
      if refund
        refund = refund.toHex()
#        console.log "refunds transaction for #{server.context.id} : #{refund}"
        res.send {hex:refund}
      else
        res.sendStatus 400

  processPayment:(req, res)->
    @execute req, res, true, (server)=>
      amount = server.processPayment req.body.tx
      if !amount
        res.sendStatus 400
      else
        @db.collection("channel").update {id:server.context.id}, {$set:server.context.toJSON()}, (err)->
          if err?
            res.sendStatus 500
          else
            console.log "new payment for #{server.context.id}: #{amount} total #{server.context.paidAmount}"
            res.send {paidAmount:server.context.paidAmount}


  execute:(req, res, txRequired, next)->
    if !req.body.channel? or (txRequired and !req.body.tx?)
      res.sendStatus 400
    else
      @db.collection("channel").findOne {id:req.body.channel}, (err, data)=>
        if err
          res.sendStatus 500
        else
          if !data?
            res.sendStatus 404
          else
            context = new ChannelServerContext @network
            context.fromJSON data
            context.id = req.body.channel
            server = new ChannelServer context
            next server


module.exports = Controller