express = require('express')
routes = require('./routes')
http = require('http')
path = require('path')
lingua  = require('lingua')

require './compile'
require './i18n'

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
	app.use routes.user.auth_user
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
	title: (t)-> @lingua['title_' + t]

app.get '/', routes.index
app.all '/login', routes.user.login
app.all '/register', routes.user.register
app.get '/logout', routes.user.logout
app.get '/new', routes.new
app.get '/game/:game/:id', routes.game
app.get '/attend/:id', routes.attend
app.get '/quit/:id', routes.quit
app.get '/test', (req, res)-> res.render 'test'
app.get '/u/:id', routes.user_page
app.get '/u', routes.user_page
app.get '/delete/:id', routes.delete
app.get '/dapu', routes.dapu
app.all '/comment', routes.comment
app.all '/blog', routes.blog
app.get '/follow/:uid', routes.follow
app.get '/unfollow/:uid', routes.unfollow
app.get '/surrender/:gid', routes.surrender
app.get '/delete_blog/:blog_id', routes.delete_blog
app.get '/history/:id', routes.history
app.get '/invite/:receiver', routes.send_invite
app.post '/invite', routes.send_invite
app.get '/receive_invite/:sender', routes.receive_invite


server = http.createServer(app).listen app.get('port'), ->
	console.log "Express server listening on port " + app.get('port')

routes.io = require('socket.io').listen server

#required by heroku
routes.io.configure ->
	routes.io.set "transports", ["xhr-polling"]
	routes.io.set "polling duration", 10