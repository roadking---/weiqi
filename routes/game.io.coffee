_ = require 'underscore'
api = require '../api'
user = require './user'

module.exports = (io, socket)->
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
		
		socket.on 'room', (room)->
			socket.join room
			console.log 'room ' + room
			socket.set 'gid', room
		
		socket.on 'disconnect', ->
			socket.get 'gid', (err, gid)->
				return if err 
				socket.get 'uid', (err, uid)->
					socket.broadcast.to(gid).emit 'player_disconnect', uid
				
		socket.on 'move', (req, cb)->
			socket.get 'gid', (err, gid)->
				return cb? fail:err if err 
				api.get_game gid, (err, game)-> 
					console.log 'move: ' + JSON.stringify req
					return cb? fail:err.message if err
					
					if game.status isnt 'started'
						console.error "#{gid} not started"
						return cb? fail:"#{gid} not started"
					
					socket.get 'uid', (err, uid)->
						return cb? fail:err.message if err 
						if uid not in game.players
							console.error "#{uid} is not a player in #{gid}"
							return cb? fail:'you are not a player'
						
						if game.next isnt req.player
							console.error "it is turn for #{game.next} and not for #{req.player}"
							return cb? fail:'it is not your turn'
						if game.seats[game.next] isnt uid
							console.error "#{uid} is not the player of #{game.next}"
							return cb? fail:"you are not the player of #{game.next}"
						req.n ?= game.moves.length
						
						next = if game.next is 'black' then 'white' else 'black'
						api.move gid, {next:next, move:req}, (err, rlt)->
							return cb? fail:(err.message ? 'unknown error'), gid:gid if err
							socket.get 'user', (err, user)-> console.info "move: #{user}: " + JSON.stringify req if not err
							socket.broadcast.to(gid).emit 'move', [req], next
							cb? success:true, next:next
		
		socket.on 'comment', (gid, comment, cb)->
			socket.get 'gid', (err, gid)->
				return cb? fail:err if err 
				api.add_comment gid, comment, ->
					api.get_user comment.author, (err, author)->
						comment.nickname = author.nickname
						io.of('/weiqi').in(gid).emit 'comment', comment
		
		socket.on 'retract', (cb)->
			socket.get 'gid', (err, gid)->
				return cb? fail:err if err 
				socket.get 'uid', (err, uid)->
					return cb 'fail' if err
					api.retract uid, gid, (err)->
						if err
							cb 'fail' if err
						else
							socket.broadcast.to(gid).emit 'retract', uid
							cb 'success'
		
		socket.on 'taking_seat', (req, cb)->
			socket.get 'gid', (err, gid)->
				return cb? fail:err if err 
				socket.get 'uid', (err, uid)->
					return cb? fail:err if err 
					console.info "taking seat: #{uid} #{req}"
					api.taking_seat gid, _.object([[req,uid]]), (err, seats, all_arrived)->
						if err
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
								socket.broadcast.to(gid).emit 'taking_seat', seats
								if all_arrived
									api.start_game gid, (err)->
										if not err
											io.of('/weiqi').in(gid).emit 'start', seats, 'black'
											
		socket.on 'call_finishing', (msg, cb)->
			console.log "call_finishing #{msg}"
			socket.get 'gid', (err, gid)->
				return cb? fail:err if err
				socket.get 'uid', (err, uid)->
					return cb? fail:err if err
					api.call_finishing gid, uid, msg, (err)->
						if err
							cb? err
						else
							socket.broadcast.to(gid).emit 'call_finishing', msg
							cb?()