_ = require 'underscore'
api = require '../api'
async = require 'async'
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
			socket.set 'gid', room
			socket.get 'uid', (err, uid)->
				console.log "room #{room} <- #{uid}"
		
		prepare = (cb)->
			socket.get 'gid', (err, gid)->
				return cb? err if err
				socket.get 'uid', (err, uid)->
					return cb? err if err
					cb? undefined, gid, uid
		
		socket.on 'disconnect', ->
			prepare (err, gid, uid)->
				socket.broadcast.to(gid).emit 'player_disconnect', uid
				
		socket.on 'move', (step, cb)->
			prepare (err, gid, uid)->
				return cb? fail:err if err
				api.get_game gid, (err, game)-> 
					if game.status isnt 'started'
						console.error "#{gid} not started"
						return cb? fail:"#{gid} not started"
					
					if uid not in game.players
						console.error "#{uid} is not a player in #{gid}"
						return cb? fail:'you are not a player'
					
					if game.next isnt step.player
						console.error "it is turn for #{game.next} and not for #{step.player}"
						return cb? fail:'it is not your turn'
					if game.seats[game.next] isnt uid
						console.error "#{uid} is not the player of #{game.next}"
						return cb? fail:"you are not the player of #{game.next}"
					step.n ?= game.moves.length
					
					next = if game.next is 'black' then 'white' else 'black'
					api.move gid, {next:next, move:step}, (err, rlt)->
						return cb? fail:(err.message ? 'unknown error'), gid:gid if err
						socket.get 'user', (err, user)-> console.info "move: #{user}: " + JSON.stringify step if not err
						socket.broadcast.to(gid).emit 'move', next, step, taken=_.chain(rlt.block_taken).flatten().pluck('n').value()
						cb? success:true, step:step, next:next, taken:taken
		
		socket.on 'comment', (gid, comment, cb)->
			prepare (err, gid, uid)->
				return cb? fail:err if err
				comment.author ?= uid
				api.add_comment gid, comment, ->
					api.get_user comment.author, (err, author)->
						comment.author_nickname = author.nickname
						comment.author_title = author.title
						io.of('/weiqi').in(gid).emit 'comment', comment
		
		socket.on 'fetch_comment', (gid, tag, step, start, num, cb)->
			prepare (err, gid, uid)->
				return cb? fail:err if err
				api.get_comments gid, (tag ? api.COMMENTS), step, start, num, (err, comments)->
					cb comments if not err
		
		socket.on 'retract', (cb)->
			prepare (err, gid, uid)->
				return cb? fail:err if err 
				api.retract uid, gid, (err)->
					if err
						cb 'fail' if err
					else
						socket.broadcast.to(gid).emit 'retract', uid
						cb 'success'
		
		socket.on 'taking_seat', (seat, cb)->
			prepare (err, gid, uid)->
				return cb? fail:err if err
				console.info "taking seat: #{uid} #{seat}"
				
				api.get_game gid, (err, game)->
					return cb success:false if game.status isnt 'taking_seat' or not (uid in game.players)
					seats = \
					if seat is 'black'
						black: uid
						white: _.without(game.players, uid)[0]
					else if seat is 'white'
						white: uid
						black: _.without(game.players, uid)[0]
					else
						_.chain(['black', 'white']).shuffle().zip(game.players).object().value()
					api.taking_seat gid, seats, (err, seats, all_arrived)->
						return cb? fail:err if err
						if all_arrived
							console.log 'start game'
							io.of('/weiqi').in(gid).emit 'start', seats, 'black'
		
		socket.on 'call_finishing', (msg)->
			if msg is 'suggest'
				[msg, stone, suggest, cb] = arguments
				prepare (err, gid, uid)->
					return if err
					api.suggest_finishing gid, uid, stone, suggest, (err)->
						if err
							console.error err
						else
							socket.broadcast.to(gid).emit 'call_finishing', msg, stone, suggest
							cb?()
			else
				[msg, cb] = arguments
				prepare (err, gid, uid)->
					return if err
					if msg is 'confirm'
						api.suggest_finishing gid, uid, 'confirm', (err, rlt)->
							return if err
							if rlt
								api.calc gid, (err, calc_rlt)->
									return if err
									api.end_game gid, calc_rlt, (err, game_rlt)->
										return if err
										api.game_rating game_rlt, (err, players)->
											console.log players
											socket.broadcast.to(gid).emit 'call_finishing', 'confirm', uid, game_rlt
											cb game_rlt
							else
								socket.broadcast.to(gid).emit 'call_finishing', 'confirm', uid
								cb()
					else
						api.get_game gid, (err, game)->
							return if err
							player = _.invert(game.seats)[uid]
							api.call_finishing gid, uid, msg, (err)->
								if err
									cb? err
								else
									if msg is 'accept'
										api.analyze gid, true, (err, analysis)->
											socket.broadcast.to(gid).emit 'call_finishing', msg, analysis
											cb analysis
									else
										socket.broadcast.to(gid).emit 'call_finishing', msg, player
										cb?()