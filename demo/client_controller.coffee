{ChannelClientContextFactory, ChannelClientContext} = require "../channel_client_context"
ChannelClient = require "../channel_client"
{Transaction, Address, ECPubKey, ECKey} = require "bitcoinjs-lib"

class Controller

  constructor:(@network, @node, @db, @channelServer, @notifier)->
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
    @db.collection("channel").findOne {depositAddress:{$in:outputs}}, (err, contextData)=>
      if err? or not contextData? or not contextData.active
        if err? then console.log "error : ",err
      else
        console.log "transaction ins: ",transaction.ins
        context = new ChannelClientContext @network
        context.fromJSON contextData
        client = new ChannelClient context
        contract = client.createContract hex
        refund = client.createRefund()
        if client and refund
          @channelServer.post "/refund", {channel: contextData.id, tx: refund.toHex()}, (err, result)=>
            if err?
              console.log "failed to create refund tx: ",err
            else
              updates = context.toJSON()
              updates.refundTx = result.tx
              updates.id = contextData.id
              updates.active = contextData.active
              @node.send contract.toHex(), (err)=>
                if err?
                  console.log "failed to send transaction : ",err
                else
                  console.log "contract sent"
                  @db.collection("channel").update {id:updates.id}, {$set:updates}, (err)=>
                    if err?
                      console.log "failed to save context : ",err
                    else
                      console.log "channel #{updates.id} started"
                      @notifier.emit 'update', updates
        else
          console.log "failed to create contract"
    undefined


  open:(req, res)->
    context = ChannelClientContextFactory.Create @network
#    context = ChannelClientContextFactory.CreateFromKey @network, ECKey.fromWIF "L36oQYkkqDrE7wzyHGBAoUVHug2daua3sSmuSFkWFTT76hTJgetV"
    client = new ChannelClient context
    @channelServer.post "/request", {pubkey: context.clientKey.pub.toHex()}, (err, response)=>
      if err?
        res.sendStatus 500
      else
        client.setServerKey response.pubkey
        data = context.toJSON()
        data.id = context.getContractAddress().toString()
        data.depositAddress = context.getClientAddress().toString()
        @node.registerAddresses data.depositAddress, false, (err)=>
          if err?
            res.sendStatus 500
          else
            data.active = true
            @db.collection("channel").insert data, (err)=>
              if err?
                res.sendStatus 500
              else
                res.send data


  status:(req, res)->
    @execute req, res, (client)->
      context = client.context
      res.send status:if !context.active then "closed" else if context.refundTx? then "open" else "pending"


  pay:(req, res)->
    if !req.body.amount?
      res.send 400
    else
      @execute req, res, (client)=>
        payAmount = parseInt req.body.amount
        tx = client.createPayment payAmount
        if !tx
          console.log "failed to create payment"
          res.sendStatus 400
        else
          console.log "tx=",tx
          console.log "context=",client.context.toJSON()
          hex = tx.toHex()
          @channelServer.post "/pay", {channel:req.body.channel, tx:hex}, (err, data)=>
            if err?
              console.log "payment failed error :", err
              res.sendStatus 500
            else
              @db.collection("channel").update {id:req.body.channel}, {$set:client.context.toJSON()}, (err)->
                if err?
                  console.log "failed to save context: ",err
                else
                  res.send paymentID:tx.getId(), contractAmount:client.context.contractAmount, paid:data.paidAmount


  close:(req, res)->
    @execute req, res, ()=>
      @db.collection("channel").update {id:req.body.channel}, {$set:{active:false}}, (err)=>
        if err?
          res.sendStatus 500
        else
          @channelServer.post "/close", {channel:req.body.channel}, (err, data)=>
            if err?
              res.sendStatus 500
            else
              res.sendStatus 200, data


  refund:(req, res)->
    @execute req, res, (client)=>
      if !client.context.refundTx?
        res.send 400
      else
        @node.send client.context.refundTx.toHex(), (err)=>
          if err?
            console.log "channel #{client.context.getContractAddress()} failed to send refund tx: ",err
            res.sendStatus 500
          else
            console.log "channel #{client.context.getContractAddress()} refund transaction sent "
            res.sendStatus 200


  list:(req, res)->
    @db.collection("channel").find().toArray (err, channels)->
      if err?
        res.send 500
      else
        res.send channels



  execute:(req, res, next)->
    if !req.body.channel?
      res.send 400
    else
      @db.collection("channel").findOne {id:req.body.channel}, (err, data)=>
        if err? or not data?
          res.sendStatus 500
        else
          context = new ChannelClientContext @network
          context.fromJSON data
          context.active = data.active
          client = new ChannelClient context
          next client



module.exports  = Controller