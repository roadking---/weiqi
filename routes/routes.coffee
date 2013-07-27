routes = require('./index')
_ = require 'underscore'
api = require '../api'

exports.set = (app)->
	app.param 'gid', (req, res, next, gid)->
		api.get_game gid, (err, game)->
			if err
				next err
			else
				req.game = game
				next()
	app.param 'ref_user', (req, res, next, ref_user)->
		api.get_user ref_user, (err, ref_user)->
			if err
				next err
			else
				req.ref_user = ref_user
				next()
	
	app.get '/', routes.index
	app.all '/login', routes.user.login
	app.all '/register', routes.user.register
	app.get '/logout', routes.user.logout
	app.get '/new', routes.new
	app.get '/game/:game/:gid', routes.game
	app.get '/attend/:id', routes.attend
	app.get '/quit/:id', routes.quit
	app.get '/test', (req, res)-> res.render 'test'
	app.get '/u/:id', routes.user_page
	app.get '/u', routes.user_page
	app.get '/delete/:gid', routes.delete
	app.get '/dapu', routes.dapu
	app.all '/comment', routes.comment
	app.all '/blog', routes.blog
	app.get '/follow/:uid', routes.follow
	app.get '/unfollow/:uid', routes.unfollow
	app.get '/surrender/:gid', routes.surrender
	app.get '/delete_blog/:blog_id', routes.delete_blog
	app.get '/history/:id', routes.history
	app.get '/invite/:ref_user', routes.send_invite
	app.post '/invite', routes.send_invite
	app.get '/receive_invite/:ref_user', routes.receive_invite