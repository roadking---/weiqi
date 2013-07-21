_ = require 'underscore'
maxmind = require('maxmind')
api = require '../api'
flow = require '../api/flow'
live = require './live'
jade = require 'jade'


_.each 'user'.split(' '), (x)->
	exports[x] = require './' + x

#maxmind.init './GeoIP.dat', indexCache:true
exports.index = (req, res, next)->
	ip = req.query.ip or req.headers['x-forwarded-for'] or req.ip
	ip = '119.254.243.114'
	#country = maxmind.getCountry ip
	
	flow.group [
		(cb)->
			api.client.zrange 'weiqi_pending', 0, -1, (err, pendings)->
				api.get_game pendings, (err, pendings)->
					cb 'pendings', pendings = _.reject pendings, (x)-> req.session.user and req.session.user.id in x.players
		(cb)->
			if req.session.user
				api.client.zrange [req.session.user.id, 'weiqi'].join('|'), 0, -1, (err, attendings)->
					api.get_game attendings, (err, attendings)->
						cb 'attendings', attendings
			else
				cb()
		(cb)->
			api.fetch_live_shows (err, live_shows)->
				return cb() if err
				if live_shows?.length
					api.get_game live_shows[0], (err, live_show)->
						cb 'live_show', live_show
				else
					cb()
	], ->
		games = _.chain(arguments).toArray().compact().object().value()
		blog_id = req.session.user?.id ? 'test'
		api.get_page blog_id,  (err, blogs)->
			api.get_refs {blogs:blogs, games:_.chain(games).values().flatten().compact().pluck('id').value()}, (err, refs)->
				res.render 'home',
					refs: refs
					games: games
					blogs: blogs
					blog_id: blog_id


exports.new = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	
	api.init_game {initiator:req.session.user.id, type: 'weiqi', social:true, players:[req.session.user.id]}, (err, gid)->
		next err if err
		multi = api.client.multi()
		multi.zadd 'weiqi_pending', new Date().getTime(), gid
		multi.exec (err)->
			next err if err
			res.redirect "/game/weiqi/#{gid}"
		
exports.game = (req, res, next)->
	gid = req.game.id
	api.get_comments gid, api.COMMENTS, (err, comments)->
		return next err if err
		api.get_blogs gid, (err, blogs)->
			return next err if err
			api.get_refs {blogs:blogs, games:[gid]}, (err, refs)->
				return next err if err
				_.chain(comments).values().flatten().each (x)-> x.nickname = refs[x.author].nickname
				res.render 'game', 
					gid: gid
					game:req.game
					refs: refs
					comments: comments
					blogs: blogs
					players: if req.game.seats
						_.chain(req.game.seats).pairs().map((x)->[
							x[0], 
							id: x[1], nickname: refs[x[1]].nickname, title: res.locals.title(refs[x[1]].title)
						]).object().value()
							
	
	if not (req.game.status in ['ended'])
		if not api.cache.get gid + '_socket'
			console.info "listen to /weiqi/#{gid}"
			exports.io.of("/weiqi/#{gid}").on 'connection',  (socket)->
				live.start exports.io, socket, gid
									
exports.attend = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	api.player_attend req.params.id, req.session.user.id, (err, all_arrived)->
		if err
			next err
		else
			console.info "attend: #{req.params.id} <- #{req.session.user.id}"
			exports.io.of("/weiqi/#{req.params.id}").emit 'attend', uid:req.session.user.id, name:req.session.user.nickname
			if all_arrived
				exports.io.of("/weiqi/#{req.params.id}").emit 'taking_seat', 'start'
			res.redirect "/game/weiqi/#{req.params.id}"

exports.delete = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	
	return next err if err
	if req.game.players.length > 1
		return next new Error "should not delete"		
	api.discard_game req.params.id, (err)->
		return next err if err
		multi = api.client.multi()
		multi.zrem 'weiqi_pending', req.params.id
		multi.zrem 'weiqi_started', req.params.id
		multi.exec()
		res.redirect "/u/#{req.session.user.id}"
	
exports.quit = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	api.player_quit req.params.id, req.session.user.id, (err)->
		if err
			next err
		else
			console.info "quit: #{req.params.id} <- #{req.session.user.id}"
			exports.io.of("/weiqi/#{req.params.id}").emit 'quit', uid:req.session.user.id, name:req.session.user.nickname
			res.redirect "/game/weiqi/#{req.params.id}"
###
m = api.client.multi()
m.del ['u1', 'inviting'].join('|')
m.del ['u1', 'invited'].join('|')
m.del ['u2', 'inviting'].join('|')
m.del ['u2', 'invited'].join('|')
m.exec()
###

exports.user_page = (req, res, next)->
	uid = req.params.id
	if not uid
		if not req.session.user
			return res.redirect '/login'
		uid = req.session.user.id
	
	console.log new Date().getTime() + " 1"
	api.get_user uid, (err, user)->
		return next err if err
		console.log new Date().getTime() + " 2"
		query =
			current: (m)-> m.zrange [uid, 'weiqi'].join('|'), 0, -1
			recent_history: (m)-> m.zrevrange [uid, 'history'].join('|'), 0, 5
			total_games: (m)-> m.get [uid, 'total_games'].join('|')
			wins: (m)-> m.get [uid, 'wins'].join('|')
			losses: (m)-> m.get [uid, 'losses'].join('|')
			followed: (m)-> m.srandmember [uid, 'followed'].join('|'), 5
			friends: (m)-> m.srandmember [uid, 'friends'].join('|'), 5
			
		if req.session.user
			query.is_friend = (m)-> m.sismember [req.session.user.id, api.RELATED.FRIENDS].join('|'), uid
			query.is_followed = (m)-> m.sismember [req.session.user.id, api.RELATED.FOLLOWED].join('|'), uid
		
		m = api.client.multi()
		_.chain(query).values().each (fn)-> fn m
		m.exec (err, replies)->
			return next err if err
			console.log query = _.chain(query).keys().zip(replies).object().value()
			console.log new Date().getTime() + " 3"
			flow.group [
				(cb)->
					game_ids = _.chain(query).pick('current', 'recent_history').values().flatten().value()
					api.get_game game_ids, (err, games)->
						return next err if err
						console.log new Date().getTime() + " 3.1"
						tmp = _.chain(game_ids).zip(games).object().value()
						cb games = _.chain(query).pick('current', 'recent_history').pairs().map((x)->
							x[1] = _.map x[1], (y)-> tmp[y]
							x
						).object().value()
				(cb)->
					api.get_blogs uid, (err, blogs)->
						console.log new Date().getTime() + " 3.2"
						cb blogs
				(cb)->
					api.get_sent_invitation uid, (err, sent_invites)->
						console.log new Date().getTime() + " 3.3"
						cb sent_invites
				(cb)->
					api.get_received_invitation uid, (err, received_invites)->
						console.log new Date().getTime() + " 3.4"
						cb received_invites
			], ->
				console.log new Date().getTime() + " 4"
				[games, blogs, sent_invites, received_invites] = _.chain(arguments).toArray().pluck(0).value()
				api.get_refs {
					blogs: blogs
					games: _.chain(games).values().flatten().pluck('id').value()
					users: _.chain([uid, query.invite_sent, query.followed, query.friends]).flatten().uniq().value()
				}, (err, refs)->
					console.log new Date().getTime() + " 5"
					res.render 'user_page', 
						me:user
						games: games
						refs: refs
						blogs: blogs
						isFollowed: query.is_friend or query.is_followed
						query: query
						sent_invites: sent_invites
						received_invites: received_invites

exports.dapu = (req, res, next)->
	opts =
		status: 'draft'
		player_num: 2
		version: .1
		next: 'black'
	res.render 'dapu', opts:opts

exports.comment = (req, res, next)->
	if req.method is 'POST'
		api.add_comment req.body.game, req.body.comment, ->
			res.json success:true

exports.blog = (req, res, next)->
	if not req.session.user
		return res.json fail:true
		
	if req.method is 'POST'
		post =
			text: req.body.text
			author: req.session.user.id
		api.send_post req.session.user.id, post, (err, pid)->
			if err
				res.json fail:true
			else
				res.json success:true
	else
		return res.json fail:true if not (req.query.tag in ['next', 'recent'])
		api.get_page req.query.blog_id, req.query.tag, (err, blogs)->
			return res.send 'error' if err
			api.get_refs {blogs:blogs}, (err, refs)->
				return res.send 'error' if err
				return res.render 'widget/blogs', blogs:blogs, refs:refs
				res.json
					blogs:blogs
					success:true
					refs:_.chain(refs).pairs().map((x)->[
						x[0]
						_.pick x[1], 'nickname', 'title'
					]).object().value()

exports.follow = (req, res, next)->
	if not req.session.user
		return res.json success:false
	api.follow req.session.user.id, req.params.uid, (err, tag)->
		if err
			res.json success:false
		else
			res.json success:true, tag:tag

exports.unfollow = (req, res, next)->
	if not req.session.user
		return res.json success:false
	api.unfollow req.session.user.id, req.params.uid, (err)->
		console.log err
		if err
			res.json success:false
		else
			res.json success:true

exports.surrender = (req, res, next)->
	if not req.session.user
		return res.json {error:'please login'}
	
	return next new Error "not a player in the game" if not (req.session.user.id in req.game.players)
	
	api.surrender req.params.gid, req.session.user.id, (err, rlt)->
		return next err if err
		api.game_rating rlt, (err, players)->
			return next err if err
			console.log players
			exports.io.of("/weiqi/#{req.params.gid}").emit 'surrender', req.session.user.id
			res.redirect "/game/weiqi/#{req.params.gid}"

exports.delete_blog = (req, res, next)->
	if not req.session.user
		return res.json error:'please login'
	
	api.get_blogs [req.params.blog_id], (err, blogs)->
		if err or not blogs.length
			return res.json error:'failed'
		if req.session.user.id isnt blogs[0].author
			return res.json error:'it is not your post'
		api.delete_post req.params.blog_id, (err)->
			if err
				res.json error:'failed'
			else
				res.json success:true

exports.history = (req, res, next)->
	api.get_user uid = req.params.id, (err, user)->
		
		api.client.zrevrange [[uid, 'records'].join('|'), 0, -1, 'WITHSCORES'], (err, records)->
			return next err if err
			console.log records = _.chain(records).map((r)-> JSON.parse r).groupBy((x,i)->Math.floor i/2).values().map((x)->
				x[0].ts = x[1]
				x[0]
			).value()
		
			api.get_game _.pluck(records, 'gid'), (err, games)->
				return next err if err
				api.get_refs {games:_.pluck(games, 'id')}, (err, refs)->
					res.render 'history',
						me: user
						games: _.chain(games).zip(records).map((x)->
							x[0].record = x[1]
							x[0]
						).value()
						refs: refs

exports.send_invite = (req, res, next)->
	if not req.session.user
		return res.redirect '/login'
	if req.method is 'GET'
		receiver = req.ref_user
		if req.query.cancel
			api.cancel_invite req.session.user.id, receiver.id, (err)->
				if err
					next err
				else
					res.redirect '/u'
		else
			api.get_invitation req.session.user.id, receiver.id, (err, invitation)->
				res.render 'send_invite',
					receiver: receiver
					invitation: invitation
	else if req.method is 'POST'
		console.log req.body
		api.invite req.session.user.id, req.body.receiver, (err, invite_id)->
			return next err if err
			res.redirect '/u'


exports.receive_invite = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	
	sender = req.ref_user
	if req.query.accept
		api.take_invitation sender.id, req.session.user.id, (err, gid)->
			return next err if err
			res.redirect "/game/weiqi/#{gid}"
	else
		api.get_invitation sender.id, req.session.user.id, (err, invitation)->
			return next err if err
			res.render 'receive_invite',
				sender: sender
				invitation: invitation