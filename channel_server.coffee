{Address, TransactionBuilder, Transaction, opcodes, Script, ECKey} = require "bitcoinjs-lib"



class ChannelServer
  constructor:(@context)->

  initContract:(hex)->
    #toDo: use transaction or hex
    builder = TransactionBuilder.fromTransaction Transaction.fromHex hex
    try
      builder.build()
      for input in builder.inputs
        script = input.redeemScript||input.prevOutScript
        signatureHash = builder.tx.hashForSignature(0, script, input.hashType)
        for pubKey,i in input.pubKeys
          if !pubKey.verify(signatureHash, input.signatures[i])
            return false
      @context.contractAmount = @_findOutput builder, @context.getContractAddress().toString()
      if !@context.contractAmount then return false
      @context.contractID = builder.tx.getId()

      return true
    catch e
      console.log e.message
      return false

  signRefund:(hex, lockTime)->
    builder = @_decodeAndVerify hex
    if builder == false then return false
    if (lockTime? and builder.tx.locktime != lockTime) or (!lockTime? and builder.tx.locktime < Date.now()/1000 + 864000)
      console.log "invalid lock time (expected: ",lockTime," got:",builder.tx.locktime
      return false
    builder.sign 0, @context.serverKey
    builder.build()


  processPayment:(hex)->
    if !@_isContractReady()
      console.log "contract not ready"
      return 0

    tx = @_decodeAndVerify(hex)
    if tx == false then return false
    amount = @_findOutput tx, @context.getServerAddress().toString()
    if amount > @context.contractAmount or amount <= @context.paidAmount
      console.log "invalid amount"
      return 0
    @context.paymentTx = tx.buildIncomplete()
    paid = amount - @context.paidAmount
    @context.paidAmount = amount
    return paid

  _findOutput:(builder, destination)->
    for output in builder.tx.outs
      address = Address.fromOutputScript output.script, @context.network
      if address.toString() == destination
        return output.value
    return 0

  getCloseTransaction:()->
    if !@_isContractReady()
      console.log "contract not ready"
      return false
    return if @context.paymentTx? then @signTransaction @context.paymentTx else false

  signTransaction:(hex)->
    builder = @_decodeAndVerify hex
    if builder == false then return false
    builder.sign 0, @context.serverKey
    return builder.build()

  verify:(hex)->
    return @_decodeAndVerify(hex) != false


  _decodeAndVerify:(tx)->
    if tx instanceof TransactionBuilder
      builder = tx
    else
      if ! (tx instanceof Transaction)
        tx = Transaction.fromHex tx
      else
      builder = TransactionBuilder.fromTransaction tx
    try
      builder.buildIncomplete()
      if builder.inputs.length > 1
        console.log "invalid inputs"
        return false
      input = builder.inputs[0]
      if !input.redeemScript?
        console.log "invalid redeem script"
        return false
      signatureHash = builder.tx.hashForSignature(0, input.redeemScript, input.hashType)
      if !@context.clientPubKey.verify signatureHash, input.signatures[0]
        console.log "invalid signature"
        return false
      return builder
    catch e
      console.log e.message
      return false



  _isContractReady:()->
    return @context.contractAmount? and @context.contractAmount and @context.contractID?


module.exports = ChannelServer
