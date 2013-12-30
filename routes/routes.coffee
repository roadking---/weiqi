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
	
	app.get '/', (req, res)->
		res.set 'Cache-Control':"max-age=#{60*60*24*5}"
		res.render 'home'
	app.get '/json/home', routes.home
	app.all '/login', routes.user.login
	app.all '/register', routes.user.register
	app.get '/logout', routes.user.logout
	app.all '/new', routes.new
	app.get '/game/:gid', (req, res)->
		api.get_refs games:[req.params.gid], (err, refs)->
			#res.set 'Cache-Control':"max-age=#{60*60*24*5}"
			res.render 'game/connected', game:req.game, refs:refs
	app.get '/json/connected/:gid', routes.connected
	app.get '/attend/:id', routes.attend
	app.get '/quit/:id', routes.quit
	app.get '/test', (req, res)-> 
		console.time 'a'
		res.render 'test'
	app.get '/u/:ref_user', (req, res)-> 
		res.set 'Cache-Control':"max-age=#{60*60*24*5}"
		res.render 'u', ref_user:req.ref_user
	app.get '/u', (req, res)-> res.render 'u'
	app.get '/json/u/:ref_user', routes.u
	app.get '/json/u', routes.u
	app.get '/delete/:gid', routes.delete
	app.get '/delete_post/:post_id', routes.delete_post
	app.get '/dapu', routes.dapu
	app.all '/blog', routes.blog
	app.get '/follow/:uid', routes.follow
	app.get '/unfollow/:uid', routes.unfollow
	app.get '/surrender/:gid', routes.surrender
	app.get '/history/:ref_user', (req, res)-> res.render 'history', ref_user:req.ref_user
	app.get '/json/history/:ref_user', routes.history
	app.get '/invite/:ref_user', routes.send_invite
	app.post '/invite', routes.send_invite
	app.get '/receive_invite/:ref_user', routes.receive_invite
	app.get '/xxx', (req, res)->
		res.send """
		<html><body>
		<form method='post' action='/xxx'>
			<input type='hidden' value='ok'>
			<input type='submit'>
		</form>
		</body></html>
		"""
	app.post '/xxx', (req, res)->
		console.log req.body
	app.get '/tutorials', (req, res)->res.render 'tutorials/index'
	app.get '/docs/:doc', (req, res)->res.render 'docs/' + req.params.doc