_ = require 'underscore'
#maxmind = require('maxmind')
api = require '../api'
async = require 'async'
jade = require 'jade'

_.each 'user'.split(' '), (x)->
	exports[x] = require './' + x

#maxmind.init './GeoIP.dat', indexCache:true
exports.home = (req, res, next)->
	ip = req.query.ip or req.headers['x-forwarded-for'] or req.ip
	ip = '119.254.243.114'
	#country = maxmind.getCountry ip
	
	blog_id = req.session.user?.id ? 'test'
	async.parallel [
		(cb)->
			api.client.zrange 'weiqi_pending', 0, -1, (err, pendings)->
				if pendings.length
					api.get_game pendings, (err, pendings)->
						cb undefined, ['pendings', _.chain(pendings).reject((x)-> req.session.user and req.session.user.id in x.players).pluck('id').value()]
				else
					cb()
		(cb)->
			if req.session.user
				api.client.zrange [req.session.user.id, 'weiqi'].join('|'), 0, -1, (err, attendings)->
					cb undefined, ['attendings', attendings]
			else
				cb()
		(cb)->
			api.fetch_live_shows (err, live_show)->
				return cb() if err
				cb undefined, ['live_show', live_show]
				
		(cb)->
			api.get_page blog_id,  (err, blogs)-> cb err, ['blogs', blogs]
	], (err, results)->
		return next err if err
		results = _.chain(results).compact().object().value()
		games = _.pick results, 'pendings', 'attendings', 'live_show'
		api.get_refs {games:_.chain(games).values().flatten().compact().value()}, (err, refs)->
			return next err if err
			res.set 'Content-Type': 'text/plain'
			res.send 'var data = ' + JSON.stringify
				refs: refs
				games: games
				myself: req.session.user?.id

exports.new = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	if req.method is 'POST'
		console.log req.body
		api.init_game {
			start:'auto'
			initiator:req.session.user.id
			type: 'weiqi'
			players:[req.session.user.id]
			rangzi: req.body.rangzi
			seats: if req.body.rangzi is 'none' then null else black: req.session.user.id
		}, (err, gid)->
			next err if err
			multi = api.client.multi()
			multi.zadd 'weiqi_pending', new Date().getTime(), gid
			multi.exec (err)->
				next err if err
				res.redirect "/game/#{gid}"
	else
		res.render 'game/new_game'
		
exports.connected = (req, res, next)->
	gid = req.game.id
	async.parallel [
		(cb)->api.get_comments gid, api.COMMENTS, cb
		(cb)->api.get_blogs gid, cb
	], (err, results)->
		return next err if err
		[comments, blogs] = results
		api.get_refs {blogs:blogs, games:[gid], users:[req.session.user?.id]}, (err, refs)->
			return next err if err
			_.chain(comments).values().flatten().each (x)-> x.nickname = refs[x.author].nickname
			res.json
				game:req.game
				refs: refs
				comments: comments
				blogs: blogs
				myself: req.session.user?.id

exports.attend = (req, res, next)->
	return res.redirect '/login' if not req.session.user
	api.client.zcard [req.session.user.id, 'weiqi'].join('|'), (err, num_attending_games)->
		return next err if err
		return res.render 'error/too_many_games_attending' if num_attending_games > 5
	
		api.player_attend gid=req.params.id, req.session.user.id, (err, all_arrived)->
			return next err if err
			api.client.zrem 'weiqi_pending', gid, (err)->
				console.info "attend: #{gid} <- #{req.session.user.id}"
				if all_arrived
					api.get_game gid, (err, game)->
						return next err if err
						if game.seats
							exports.io.of("/weiqi").in(gid).emit 'attend', {uid:req.session.user.id, name:req.session.user.nickname}, {start:true, seats:game.seats}
						else
							exports.io.of("/weiqi").in(gid).emit 'attend', uid:req.session.user.id, name:req.session.user.nickname
							exports.io.of("/weiqi").in(gid).emit 'taking_seat', 'start'
				else
					exports.io.of("/weiqi").in(gid).emit 'attend', uid:req.session.user.id, name:req.session.user.nickname
				res.redirect "/game/#{gid}"

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
			exports.io.of("/weiqi").in(req.params.id).emit 'quit', uid:req.session.user.id, name:req.session.user.nickname
			res.redirect "/game/weiqi/#{req.params.id}"

exports.u = (req, res, next)->
	uid = req.params.ref_user
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
		query = _.chain(query).keys().zip(replies).object().value()
		async.parallel [
			(cb)-> api.get_blogs uid, (err, blogs)-> cb err, ['blogs', blogs]
			(cb)-> api.get_sent_invitation uid, (err, sent_invites)-> cb err, ['sent_invites', sent_invites]
			(cb)-> api.get_received_invitation uid, (err, received_invites)-> cb err, ['received_invites', received_invites]
		], (err, results)->
			return next err if err
			results = _.object results
			api.get_refs {
				blogs: results.blogs
				games: _.chain(query).pick('current', 'recent_history').values().flatten().value()
				users: _.chain([uid, query.invite_sent, query.followed, query.friends]).flatten().uniq().value()
			}, (err, refs)->
				return next err if err
				res.json _.extend results, query:query, refs:refs, uid:uid, myself:req.session?.user?.id
		
exports.dapu = (req, res, next)->
	opts =
		status: 'draft'
		player_num: 2
		version: .1
		next: 'black'
	res.render 'dapu', opts:opts

exports.blog = (req, res, next)->
	return res.json fail:true if not req.session.user
		
	if req.method is 'POST'
		api.send_post req.session.user.id, {
			text: req.body.text
			author: req.session.user.id
		}, (err, pid)->
			res.json success: not err
	else
		return res.json success:false if not (req.query.tag in ['next', 'recent'])
		api.get_page req.query.blog_id, req.query.tag, (err, blogs)->
			return res.json success:false if err
			api.get_refs {blogs:blogs}, (err, refs)->
				return res.json success:false if err
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
			exports.io.of("/weiqi").in(req.params.id).emit 'surrender', req.session.user.id
			res.redirect "/game/weiqi/#{req.params.gid}"

exports.history = (req, res, next)->
	api.client.zrevrange [[req.ref_user.id, 'records'].join('|'), 0, -1, 'WITHSCORES'], (err, records)->
		return next err if err
		records = _.chain(records).map((r)-> JSON.parse r).groupBy((x,i)->Math.floor i/2).values().map((x)->
			x[0].ts = x[1]
			x[0]
		).value()
		api.get_refs {games:_.pluck(records, 'gid')}, (err, refs)->
			res.json
				uid: req.ref_user.id
				records: records
				refs: refs
				myself:req.session?.user?.id

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

exports.delete_post = (req, res, next)->
	return res.json 'please login' if not req.session.user
	console.log req.params.post_id
	api.delete_post req.params.post_id, req.session.user.id, (err)->
		res.json success: not err