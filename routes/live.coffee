_ = require 'underscore'
api = require '../api'
user = require './user'

exports.start = (io, socket, gid)->
	api.cache.set gid + '_socket', api.cache.get(gid + '_socket') + 1
	console.info "socket connect ..."
	socket.on 'disconnect', ->
		api.cache.set gid + '_socket', api.cache.get(gid + '_socket') - 1
		socket.get 'uid', (err, uid)->
			return if err
			api.get_game gid, (err, data)-> 
				return if err or not data
				if data.players and uid in data.players
					console.info "disconnect: player #{uid} left #{#gid}"
					api.disconnect uid, gid
					socket.broadcast.emit 'player_disconnect', uid
				else
					console.info "disconnect: witness #{uid ? 'anonymous'} left #{#gid}"
		
		#test and try removing it from global live show
		api.remove_live_show gid, ->
			
	socket.on 'auth', (str, cb)-> 
		console.info 'auth'
		
		if str is 'anonymous'
			socket.set 'user', 'anonymous'
			cb? 'anonymous'
		else if str is 'test cookie'
			socket.set 'user', 'test'
			socket.set 'uid', 'test'
			cb? 'test'
		else
			user.auth_user_socket str, (err, rlt)->
				if err or not rlt
					socket.set 'user', 'anonymous'
					cb? 'anonymous'
				else
					socket.set 'user', rlt.nickname
					socket.set 'uid', rlt.uid
					cb? rlt.nickname
					api.connect rlt.uid, gid
		
		socket.on 'discuss', (req, cb)->
			socket.get 'user', (err, user)->
				if not err
					console.info "discuss: #{user}: " + JSON.stringify req
			socket.broadcast.emit 'discuss', req
			cb? 'done'
		
		socket.on 'taking_seat', (req, cb)->
			socket.get 'uid', (err, uid)->
				if not err and uid
					console.info "taking seat: #{uid} #{req}"
					api.taking_seat gid, _.object([[req,uid]]), (err, seats, all_arrived)->
						if err
							console.error err
							cb? 'fail'
						else
							api.get_user _.values(seats), (err, users)->
								seats = _.chain(seats).pairs().map((x)->
									[
										x[0]
										_.pick users[x[1]], 'id', 'nickname', 'title'
									]
								).object().value()
								cb? seats
								socket.broadcast.emit 'taking_seat', seats
								if all_arrived
									api.start_game gid, (err)->
										if not err
											io.of("/weiqi/#{gid}").emit 'start', seats, 'black'
											multi = api.client.multi()
											multi.zrem 'weiqi_pending', gid
											multi.zadd 'weiqi_started', new Date().getTime(), gid
											multi.exec()
											
		socket.on 'move', (req, cb)-> 
			api.get_game gid, (err, data)-> 
				console.log 'move: ' + JSON.stringify req
				if err
					console.error err
					return cb? fail:err
				if data.status isnt 'started'
					console.error "#{gid} not started"
					return cb? fail:'game not started'
				
				socket.get 'uid', (err, uid)->
					if err 
						console.error err
						return cb? fail:err
					if uid not in data.players
						console.error "#{uid} is not a player in #{gid}"
						return cb? fail:'you are not a player'
					
					if data.next isnt req.player
						console.error "it is turn for #{data.next} and not for #{req.player}"
						return cb? fail:'it is not your turn'
					if data.seats[data.next] isnt uid
						console.error "#{uid} is not the player of #{data.next}"
						return cb? fail:"you are not the player of #{data.next}"
					req.n ?= data.moves.length
					
					next = if data.next is 'black' then 'white' else 'black'
					api.move gid, {next:next, move:req}, (err, rlt)->
						if err
							console.error err
							return cb? fail:err
						socket.get 'user', (err, user)->
							if not err
								console.info "move: #{user}: " + JSON.stringify req
						socket.broadcast.emit 'move', [req], next
						api.add_live_show gid, ->
						cb? success:true, next:next
		
		socket.on 'comment', (gid, comment, cb)->
			api.add_comment gid, comment, ->
				api.get_user comment.author, (err, author)->
					comment.nickname = author.nickname
					socket.broadcast.emit 'comment', comment
		
		socket.on 'retract', (cb)->
			socket.get 'uid', (err, uid)->
				return cb 'fail' if err
				api.retract uid, gid, (err)->
					if err
						cb 'fail' if err
					else
						socket.broadcast.emit 'retract', uid
						cb 'success'