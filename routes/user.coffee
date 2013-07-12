sanitize = require('validator').sanitize
check = require('validator').check
_ = require 'underscore'
crypto = require('crypto')
api = require '../api'

session_secret = 'secret'
auth_cookie_name = 'auth'

exports.auth_user_socket = (cookie, cb)->
	return cb undefined, false if not cookie
	
	[uid, nickname, md5_password] = api.decrypt(cookie, session_secret)?.split('\t')
	api.check_user uid, md5_password, (err, rlt)->
		if err
			cb err
		else if rlt
			cb undefined, uid:uid, nickname:nickname
		else
			cb undefined, false

exports.register = (req, res, next)->
	if req.method is 'POST'
		console.log req.body = _.chain(req.body).pairs().map((x)->[x[0], sanitize(x[1]).trim()]).object().value()
		try
			check(req.body.email).isEmail()
		catch e
			return res.render 'user/register'
		
		try
			check(req.body.password).len(6, 20)
		catch e
			return res.render 'user/register'
		
		try
			check(req.body.nickname).len(3, 20)
		catch e
			return res.render 'user/register'
		
		api.register req.body, (err, id)->
			if err
				res.render 'user/register'
			else
				res.redirect '/'
	else
		res.render 'user/register'

exports.logout = (req, res, next)->
	req.session.destroy()
	res.clearCookie auth_cookie_name, {path: '/'}
	res.redirect '/'

		
exports.login = (req, res, next)->
	if req.method is 'POST'
		data = _.chain(req.body).pairs().map((x)->[x[0], sanitize(x[1]).xss()]).object().value()
		api.login data.email, data.password, (err, id)->
			console.log err
			if err
				res.render 'user/login'
			else
				api.get_user id, (err, user)->
					return next err if err
					auth_token = api.encrypt _.chain(user).pick('id', 'nickname', 'password', 'email').values().value().join("\t"), session_secret
					res.cookie auth_cookie_name, auth_token, {path:'/', maxAge:1000*60*60*24*7}
					req.session.user = user
					res.redirect "/u/#{id}"
	else
		res.render 'user/login'
	
exports.auth_user = (req, res, next)->
	fn = ->
		res.locals.user = req.session.user
		next()
		
	if req.session.loginUser
		fn()
	else
		cookie = req.cookies[auth_cookie_name]
		if not cookie
			return fn()
		
		auth_token = api.decrypt(cookie, session_secret)
		[id] = auth_token.split('\t')
		return fn() if not id
		
		api.get_user id, (err, user)->
			if user
				req.session.user = user
			fn()