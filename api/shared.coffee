_ = require 'underscore'
redis = require 'redis'

exports.client = client = \
if process.env.REDISTOGO_URL
	rtg = require("url").parse(process.env.REDISTOGO_URL)
	client = require("redis").createClient(rtg.port, rtg.hostname)
	client.auth(rtg.auth.split(":")[1]);
	client
else
	redis.createClient()

client.on 'error', (err)->
	console.log "Error " + err
	process.exit 1

