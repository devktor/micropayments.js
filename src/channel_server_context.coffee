{Address, opcodes, Script, ECKey, ECPubKey, Transaction} = require "bitcoinjs-lib"
ChannelContext = require "./channel_context"



class ChannelServerContext extends  ChannelContext

  constructor:(@network)->

  makeRedeemScript:()-> super @clientPubKey, @serverKey.pub

  getServerAddress:()-> @serverKey.pub.getAddress @network

  getClientAddress:()-> @clientPubKey.getAddress @network

  getServerPubKey:()-> @serverKey.pub.toHex()

  toJSON:()->
    obj = super()
    obj.serverKey = @serverKey.toWIF()
    if @clientPubKey then obj.clientPubKey = @clientPubKey.toHex()
    obj.paidAmount = @paidAmount
    if @paymentTx then obj.paymentTx = @paymentTx.toHex()
    return obj

  fromJSON:(obj)->
    if obj.serverKey? then @serverKey = ECKey.fromWIF(obj.serverKey)
    if obj.clientPubKey? then @clientPubKey = ECPubKey.fromHex obj.clientPubKey
    @paidAmount = obj.paidAmount
    if obj.paymentTx?  then @paymentTx = Transaction.fromHex obj.paymentTx
    super obj

class ChannelServerContextFactory

  @Create = (network, clientPubKey)-> @CreateFromKey network, ECKey.makeRandom(), clientPubKey

  @CreateFromKey = (network, serverKey, clientPubKey)->
    context =  new ChannelServerContext network
    context.serverKey = serverKey
    context.clientPubKey = clientPubKey
    console.log "context: ",context.toJSON()
    context.makeRedeemScript()
    context.contractAmount = 0
    context.paidAmount = 0
    return context


module.exports =
  ChannelServerContext: ChannelServerContext
  ChannelServerContextFactory: ChannelServerContextFactory