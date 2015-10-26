settings = require("optimist").argv
express = require 'express'
morgan = require 'morgan'
bodyParser = require 'body-parser'
methodOverride = require 'method-override'
cors = require "cors"

{networks} = require "bitcoinjs-lib"
{MongoClient} = require "mongodb"
Node = require "./node"
ChannelServer = require "../channel_server"
ServerController = require "./server_controller"



app = express()
app.use bodyParser.urlencoded({ extended: false })
app.use morgan('dev')
app.use methodOverride()
app.use cors()

node = new Node
console.log "settings: ",settings
node.connect settings.port||8001, settings.ip

node.on "error", (err)-> throw err

btcNetwork = if settings.testnet? then networks.testnet else networks.bitcoin

controller = new ServerController btcNetwork, node

app.use "/request", (req, res)-> controller.requestChannel req, res
app.use "/refund", (req, res)-> controller.signRefund req, res
app.use "/pay", (req, res)-> controller.processPayment req, res
app.use "/close", (req, res)-> controller.closeChannel req, res


MongoClient.connect "mongodb://localhost:27017/micropayments_server", (err, db)->
  if err? then throw err
  controller.db = db
  app.listen 30001, ()-> console.log "server listening on 30001"

