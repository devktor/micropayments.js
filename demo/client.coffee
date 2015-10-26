Controller = require "./client_controller"
HTTPClient = require "./http_client"

settings = require("optimist").argv
express = require 'express'
morgan = require 'morgan'
bodyParser = require 'body-parser'
methodOverride = require 'method-override'
cors = require "cors"
path = require "path"

{MongoClient} = require "mongodb"
Node = require "./node"

{networks, ECKey} = require "bitcoinjs-lib"


app = express()
http = require('http').Server(app)
notifier = require('socket.io')(http)

app.use bodyParser.urlencoded({ extended: false })
app.use morgan('dev')
app.use methodOverride()
app.use cors()

node = new Node
console.log "settings: ",settings
node.connect settings.port||8001, settings.ip

node.on "error", (err)-> throw "failed to connect to bitcoin node : #{err}"

btcNetwork = if settings.testnet? then networks.testnet else networks.bitcoin

serverChannel = new HTTPClient settings.server_host||"localhost", settings.server_port||30001

controller = new Controller btcNetwork, node, null, serverChannel, notifier


app.use "/list", (req, res)-> controller.list req, res
app.use "/status", (req, res)-> controller.status req, res
app.use "/open", (req, res)->controller.open req, res
app.use "/close", (req, res)->controller.close req, res
app.use "/pay", (req, res)->controller.pay req, res
app.use express.static path.join "#{__dirname}/public_html", '/'


MongoClient.connect "mongodb://localhost:27017/micropayments_client", (err, db)->
  if err? then throw "failed to connect to mongo #{err}"
  controller.db = db
  http.listen 30002, ()-> console.log "server listening on 30002"
