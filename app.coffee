_ = require 'underscore'
express = require('express')
http = require('http')
path = require('path')
lingua  = require('lingua')
require './compile'
require './i18n'
jade = require 'jade'

app = express()

app.configure ->
	app.set('port', process.env.PORT || 5000)
	app.set('views', __dirname + '/views')
	app.set('view engine', 'jade')
	app.set('jsonp callback name', 'init');
	app.use(express.favicon())
	app.use(express.logger('dev'))
	app.use(express.bodyParser())
	app.use express.compress()
	app.use lingua(app, {defaultLocale: 'zh_CN', path: __dirname + '/public/i18n', storageKey: 'lang'})
	app.use(express.methodOverride())
	app.use(express.cookieParser('nav_secret'))
	app.use(express.session())
	app.use require('./routes/user').auth_user
	app.use express.csrf()
	app.use (req, res, next)->
		res.locals.csrf = req.session?._csrf
		next()
	app.use(app.router)
	app.use(require('stylus').middleware(__dirname + '/public'))
	app.use (req, res, next)->
		if _.find('underscore moment socket.io.js zepto.min socket.io .svg'.split(' '), (x)->req.path.indexOf(x) > -1)
			res.set 'Cache-Control':"max-age=#{60*60*24*30}"
		next()
	app.use(express.static(path.join(__dirname, 'public')))
	app.use (req, res, next)-> res.send 404, "Sorry can't find that!"

app.configure 'development', ->
	app.use(express.errorHandler())
	app.locals.pretty = true

fs = require 'fs'
app.locals
	_: require 'underscore'
	moment: require 'moment'
	player_titles: 'origianl_life_master national_master expert A B C D E F G H I J'.split(' ')
	

require('./routes/routes').set app


server = http.createServer(app).listen app.get('port'), ->
	console.log "Express server listening on port " + app.get('port')

require('./routes').io = io = require('socket.io').listen server

#required by heroku
io.configure ->
	io.set "transports", ["xhr-polling"]
	io.set "polling duration", 10
	io.set "log level", 1

io.of("/weiqi").on 'connection',  (socket)->
	game_io = require('./routes/game.io')
	game_io io, socket