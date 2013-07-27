_ = require 'underscore'
express = require('express')
http = require('http')
path = require('path')
lingua  = require('lingua')
routes = require('./routes')
require './compile'
require './i18n'
jade = require 'jade'

app = express()

app.configure ->
	app.set('port', process.env.PORT || 5000)
	app.set('views', __dirname + '/views')
	app.set('view engine', 'jade')
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
		res.locals.title = title_fn = (t)-> res.locals.lingua['title_' + t] ? ''
		res.locals.win_ratio_fn = (r)-> Math.round(r*1000)/10 + '%'
		user_title_fn = jade.compile(fs.readFileSync(__dirname + '/views/view_fn/user_title_fn.jade').toString(), filename: __dirname + '/views/widget/user_title.jade')
		res.locals.user_title_fn = _.wrap user_title_fn, (fn, args)->
			args.title = title_fn
			fn args
		next()
	app.use(app.router)
	app.use(require('stylus').middleware(__dirname + '/public'))
	app.use (req, res, next)->
		#if /jquery/.test(req.path) or /bootstrap/.test(req.path)
		#	res.set 'Pragma':'public', 'Cache-Control':"max-age=#{60*60*24*3}", 'Expires':new Date().add(day:3).toString('ddd, dd MMM yyyy hh:mm:ss') + ' GMT'
		next()
	app.use(express.static(path.join(__dirname, 'public')))
	app.use (req, res, next)-> res.send 404, 'Sorry cant find that!'

app.configure 'development', ->
	app.use(express.errorHandler())
	app.locals.pretty = true

fs = require 'fs'
app.locals
	_: require 'underscore'
	moment: require 'moment'
	

require('./routes/routes').set app


server = http.createServer(app).listen app.get('port'), ->
	console.log "Express server listening on port " + app.get('port')

routes.io = require('socket.io').listen server

#required by heroku
routes.io.configure ->
	routes.io.set "transports", ["xhr-polling"]
	routes.io.set "polling duration", 10
	routes.io.set "log level", 1