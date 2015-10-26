{ECKey, ECPubKey, Script, Transaction} = require("bitcoinjs-lib")
ChannelContext = require "./channel_context"



class ChannelClientContext extends ChannelContext
  constructor:(@network)->

  makeRedeemScript:()->
    super @clientKey.pub, @serverPubKey

  getClientAddress:()-> @clientKey.pub.getAddress(@network)

  getServerAddress:()-> @serverPubKey.getAddress(@network)

  toJSON:()->
    obj = super()
    obj.clientKey = @clientKey.toWIF()
    if @serverPubKey? then obj.serverPubKey = @serverPubKey.toHex()
    if @refundTx? then obj.refundTx = @refundTx.toHex()
    obj.depositAmount = @depositAmount
    obj.paidAmount = @paidAmount
    return obj

  fromJSON:(obj)->
    if obj.clientKey? then @clientKey = ECKey.fromWIF(obj.clientKey)
    if obj.serverPubKey? then @serverPubKey = ECPubKey.fromHex obj.serverPubKey
    if obj.refundTx? then @refundTx = Transaction.fromHex obj.refundTx
    @depositAmount = obj.depositAmount
    @paidAmount = obj.paidAmount
    super obj


class ChannelClientContextFactory

  @Create = (network)-> @CreateFromKey network, ECKey.makeRandom()

  @CreateFromKey = (network, clientKey)->
    context =  new ChannelClientContext network
    context.clientKey = clientKey
    context.contractAmount = 0
    context.depositAmount = 0
    context.paidAmount = 0
    return context





module.exports =
  ChannelClientContext: ChannelClientContext
  ChannelClientContextFactory: ChannelClientContextFactory