{Script, opcodes, Address} = require("bitcoinjs-lib")




class ChannelContext
  constructor:()->

  makeRedeemScript:(clientPubKey, serverPubKey)->
    stack = [opcodes.OP_2, clientPubKey.toBuffer(), serverPubKey.toBuffer(), opcodes.OP_2, opcodes.OP_CHECKMULTISIG]
    @redeemScript = Script.fromChunks stack

  getContractAddress:()->
    script = Script.fromChunks [opcodes.OP_HASH160, @redeemScript.getHash(), opcodes.OP_EQUAL]
    Address.fromOutputScript script, @network

  fromJSON:(obj)->
    if obj.redeemScript?
      @redeemScript = Script.fromASM obj.redeemScript
    else
      if @clientKey? and @serverKey then @makeRedeemScript()
    @contractID = obj.contractID
    @contractAmount = obj.contractAmount
    undefined

  toJSON:()->
    obj = {}
    if @redeemScript then obj.redeemScript = @redeemScript.toASM()
    obj.contractAmount = @contractAmount
    if @contractID? then obj.contractID = @contractID.toString "hex"
    return obj





module.exports = ChannelContext