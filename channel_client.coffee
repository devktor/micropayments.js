{Script, opcodes, Address, TransactionBuilder, Transaction, scripts, ECKey, ECPubKey} = require("bitcoinjs-lib")


class ChannelClient

  constructor:(@context)->
    @fee = 100

  setServerKey:(serverPubKey)->
    @context.serverPubKey = ECPubKey.fromHex serverPubKey
    @context.makeRedeemScript()

  createContract:(depositTxHex)->
    if !@context.serverPubKey? or !@context.redeemScript?
      console.log "invalid server key"
      return false

    depositTx = Transaction.fromHex depositTxHex
    contractAddress = @context.getContractAddress()
    contractTx = new TransactionBuilder
    depositAddress = @context.getClientAddress().toString()
    vout = 0
    for output,i in depositTx.outs
      address = Address.fromOutputScript output.script, @context.network
      if address.toString() == depositAddress
        @context.contractAmount = output.value
        vout = i
        break

    if !@context.contractAmount
      console.log "no deposit found"
      return false

    contractTx.addInput depositTx.getId(), vout
    @context.depositAmount = @context.contractAmount
    @context.contractAmount -= @fee

    contractTx.addOutput contractAddress, @context.contractAmount
    contractTx.sign 0, @context.clientKey

    contractTx = contractTx.build()
    @context.contractID = contractTx.getId()
    return contractTx

  verifyRefund:(hex)->
    if !@_isContractReady()
      console.log "contract not ready"
      return false

    builder = TransactionBuilder.fromTransaction Transaction.fromHex hex
    try
      builder.build()

      if builder.inputs.length != 1
        console.log "invalid transaction inputs"
        return false

      if builder.tx.outs.length != 1
        console.log "invalid transaction outputs"
        return false

      output = builder.tx.outs[0]
      destinationAddress = Address.fromOutputScript output.script, @context.network

      if destinationAddress.toString() != @context.getClientAddress().toString()
        console.log "invalid refund address"
        return false

      if output.value < @context.contractAmount - @fee
        console.log "invalid refund amount"
        return false

      input = builder.inputs[0]
      if !input.redeemScript?
        console.log "invalid redeem script"
        return false

      signatureHash = builder.tx.hashForSignature(0, input.redeemScript, input.hashType)
      if input.signatures.length != 2
        console.log "invalid signatures"
        return false

      if !@context.clientKey.pub.verify(signatureHash, input.signatures[0])
        console.log "invalid client signature"
        return false

      if !@context.serverPubKey.verify(signatureHash, input.signatures[1])
        console.log "invalid server signature"
        return false

      console.log "transaction valid"
      return true

    catch e
      console.log e.message
      return false

  createRefund:(lockTime)->
    if !@_isContractReady()
      console.log "contract not ready "
      return false
    refundTx = new TransactionBuilder
    refundTx.addInput @context.contractID, 0
    refundTx.addOutput @context.getClientAddress().toString(), @context.contractAmount - @fee
    if !lockTime? then lockTime = Date.now()/1000 + 864060
    refundTx.tx.locktime = lockTime
    @_signTransaction refundTx
    return refundTx.buildIncomplete()

  createPayment:(amount)->
    if !@_isContractReady()
      console.log "contract not ready "
      return false
    txAmount = amount + @context.paidAmount
    console.log "creating payment for : ",txAmount
    if txAmount > @context.contractAmount
      console.log "insuficient funds "
      return false

    payment = new TransactionBuilder
    payment.addInput @context.contractID, 0
    rest = @context.contractAmount - amount - @fee
    if rest<0
      txAmount += rest
    else
      payment.addOutput @context.getClientAddress().toString(), rest
    @context.contractAmount -= amount
    payment.addOutput @context.getServerAddress().toString(), txAmount
    @_signTransaction payment
    @context.paidAmount += amount
    return payment.buildIncomplete()


  _isContractReady:()->
    return @context.serverPubKey? and @context.redeemScript? and @context.contractAmount and @context.contractID?

  _signTransaction:(tx)->
    tx.sign 0, @context.clientKey, @context.redeemScript





module.exports = ChannelClient
