_ = require 'underscore'
crypto = require('crypto')
check = require('validator').check
Cache = require('expiring-lru-cache')
shared = require './shared'
rule = require './weiqi_rule'
rating = require './rating'
async = require 'async'

SERVER_STARTED = new Date().getTime()

LIVE_SHOW = exports.LIVE_SHOW = 'live'

exports.client = client = shared.client


cache = exports.cache = new Cache size:5000, expiry:20*60*1000

BLOGS_IN_PAGE = 10
STATUS = 
	INIT: 'init'
	TAKING_SEAT: 'taking_seat'
	STARTED: 'started'
	NEED_PLAYER: 'need_player'
	ENDED: 'ended'

exports.RELATED = RELATED = 
	FRIENDS: 'friends'
	FOLLOWED: 'followed'
	FOLLOWING: 'following'

USER =
	CURRENT_GAME: 'weiqi'
	PENDING_GAME: 'weiqi_pending'
	HISTORY: 'history'
	EVENT_FOLLOW: 'e_follow'
	INVITING: 'inviting'
	INVITED: 'invited'
	BLOGS: 'blogs'
	MY_BLOGS: 'my_blogs'
	NOTICE: 'notice'
	BLOG_COUNT: 'blog_count'
	BLOG_CACHE: 'blog_cache'
	CURRENT_PAGE: 'current_page'
	FOLLOWED_GAMES: 'followed_game'
	RECORDS: 'records'
	DRAWS: 'draws'
	WINS: 'wins'
	LOSSES: 'losses'
	TOTAL_GAMES: 'total_games'
GAME =
	MOVES: 'moves'
	PLAYERS: 'players'
	PLAYERS_QUIT: 'players_quit'
	STATUS: 'status'
	SEATS: 'seats'
	BLOG_COUNT: 'blog_count'
	BLOGS: 'blogs'
	MY_BLOGS: 'my_blogs'

exports.COMMENTS_PLAYERS = COMMENTS_PLAYERS = 'comments_players'
#exports.COMMENTS_NONPLAYERS = COMMENTS_NONPLAYERS = 'comments'
#exports.COMMENT_TAGS = COMMENT_TAGS = [COMMENTS_PLAYERS, COMMENTS_NONPLAYERS]
exports.COMMENTS = COMMENTS = 'comments'


md5 = (str)-> crypto.createHash('md5').update(str).digest('hex')
decrypt = exports.decrypt = (str,secret)->
	decipher = crypto.createDecipher 'aes192', secret
	dec = decipher.update str,'hex','utf8'
	dec += decipher.final 'utf8'

encrypt = exports.encrypt = (str,secret)->
   cipher = crypto.createCipher 'aes192', secret
   enc = cipher.update str, 'utf8', 'hex'
   enc += cipher.final 'hex'

exports.now = -> Math.round new Date().getTime()/1000

get_user = exports.get_user = (uid, cb)->
	if uid is 'test'
		return cb undefined, nickname:'test', title:'Great', id:'test'
	
	if not uid
		cb undefined, undefined
	else if _.isString uid
		if user = cache.get uid
			return cb undefined, user
		model = _.chain([
			_.map 'nickname password email title connect my_new_game rate'.split(' '), (x)-> [x, (m)->m.hget uid, x]
			_.map [USER.TOTAL_GAMES, USER.DRAWS, USER.WINS, USER.LOSSES], (x)-> [x, (m)->m.get [uid, x].join('|')]
		]).flatten(true).object().value()
		m = client.multi()
		_.chain(model).values().each (f)-> f m
		m.exec (err, replies)->
			return cb err if err
			user = _.chain(model).keys().zip(
				_.map replies, (x)-> if x and /^\d+$/.test(x) then Number(x) else x
			).object().value()
			return cb new Error "#{uid} not exists" if not user.email
			
			try
				if user.connect
					user.connect = JSON.parse user.connect
			catch e
				console.error "unrecognized user.connect for #{uid}:\n#{user.connect}"
				console.error e
				
			user.rate = Number user.rate if user.rate
			user.win_ratio = if user[USER.WINS] then user[USER.WINS]/user[USER.TOTAL_GAMES] else 0
			user.id = uid
			cb undefined, user
	else if _.isArray uid
		async.map uid, ((x, cb)-> get_user x, cb), (err, users)->
			cb undefined, _.chain(users).zip(uid).map((x)->[x[1], x[0]]).object().value()
		

KEY_REGISTER = 'registers'

register = exports.register = (data, cb)->
	try
		_.each 'email password'.split(' '), (f)-> check(data[f], "#{f} missing").notEmpty()
	catch e
		return cb? e
	
	client.hexists KEY_REGISTER, data.email, (err, exists)->
		return cb? err if err
		return cb? new Error "user exists for #{data.email}" if exists
		
		client.incr 'user:id', (err, id)->
			return cb? err if err
			id = 'u' + id
			
			client.hsetnx KEY_REGISTER, data.email, id, (err, reply)->
				return cb? err if err
				return cb? new Error "user exists for #{data.email}" if not reply
		
				data.password = md5 data.password
				multi = client.multi()
				for k, v of _.chain(data).pick('email', 'password', 'nickname').value()
					multi.hset id, k, v
				multi.exec (err)-> cb? err, id

discard_user = exports.discard_user = (id_or_email, cb)->
	try
		check(id_or_email).isEmail()
		client.hget KEY_REGISTER, id_or_email, (err, uid)->
			return cb? err if err
			return cb?() if not uid
			m = client.multi()
			m.del uid
			m.hdel KEY_REGISTER, id_or_email
			_.each [RELATED.FRIENDS, RELATED.FOLLOWED, RELATED.FOLLOWING, USER.EVENT_FOLLOW, USER.BLOGS, USER.BLOG_COUNT], (x)-> m.del [uid, x].join('|')
			m.exec (cb ? ->)
	catch e
		get_user id_or_email, (err, user)->
			return cb? err if err
			discard_user user.email, cb


exports.login = (email, password, cb)->
	client.hget KEY_REGISTER, email, (err, id)->
		return cb? err if err
		return cb? new Error "user not exists for #{email}" if not id
		client.hget id, 'password', (err, md5_password)->
			if md5_password isnt md5 password
				cb? undefined, new Error "wrong password for #{email}"
			else
				cb? undefined, id

exports.check_user = (uid, md5_password, cb)->
	get_user uid, (err, user)->
		if err
			cb err
		else
			cb undefined, md5_password is user.password

# life cycle methods
init_game = exports.init_game = (opts, cb)->
	if (missing = _.reject 'initiator type'.split(' '), (x)-> opts[x]).length
		return cb new Error "missing field(s) to init a game: " + missing.join(', ')
	if opts.seats
		opts.players ?= _.values opts.seats
		_.chain(opts.seats).keys().each (x)->
			return cb new Error "init_game: unknown opts.seats #{JSON.stringify opts.seats}" if not (x in ['black', 'white'])
			return cb new Error "init_game: unknown opts.seats.#{x} #{opts.seats[x]} is not a player" if not (opts.seats[x] in opts.players)
	
	opts.contract = _.clone opts
	opts = _.omit opts, 'players', 'seats', 'moves'
	get_user opts.initiator, (err, user)->
		return cb err if err
		return cb new Error "init_game: failed as #{opts.initiator} already have a game pending" if user.my_new_game
		client.incr type=opts.type, (err, num)->
			return cb err if err
			gid = [type,num].join('')
			m = client.multi()
			_.chain(opts).defaults(
				status: STATUS.INIT
				player_num: 2
				version:.1
				init_ts: exports.now()
			).omit('type').pairs().each (x)->
				switch x[0]
					when 'contract' then m.hset gid, x[0], JSON.stringify x[1]
					else
						m.hset gid, x[0], x[1]
			m.hset opts.initiator, 'my_new_game', gid
			
			m.exec (err)->
				return cb err if err
				((social, cb)->
					if social
						client.sadd [opts.initiator, USER.FOLLOWED_GAMES].join('|'), gid, ->
							((cb)->
								if opts.contract.players and opts.initiator in opts.contract.players
									if opts.contract.players.length is 1
										send_post_tpl 'init_game', 'init_and_wait', gid, opts.initiator, cb
									else if opts.contract.players.length is 2
										send_post_tpl 'init_game', 'init_and_start', gid, opts.contract.players, cb
								else
									send_post_tpl 'init_game', null, gid, cb
							) (err, pid)-> forward_post opts.initiator, null, pid, cb
					else
						cb()
				) opts.social, (err)->
					if opts.contract.players?.length
						async.eachSeries opts.contract.players, ((x, cb)->
							player_attend gid, x, (err)->cb()
						), (err)-> cb undefined, gid
					else
						cb undefined, gid


move = exports.move = (gid, data, cb)->
	get_game gid, (err, game)->
		return cb err if err
		return cb new Error "move: failed as #{gid} status #{game.status}" if game.status isnt STATUS.STARTED
		
		try
			blocks = rule.move_step game.moves, data.move
		catch e
			return cb e
						
		m = client.multi()
		m.hset gid, 'next', data.next
		m.hdel gid, 'calling_finishing'
		m.zadd [gid, 'main'].join('|'), data.move.n, JSON.stringify(data.move)
		data.block_taken = _.pluck blocks, 'block'
		if data.block_taken.length
			_.chain(data.block_taken).flatten().each (x)->
				m.zremrangebyscore [gid, 'main'].join('|'), x.n, x.n
				m.zadd [gid, 'main'].join('|'), x.n, JSON.stringify(x)
		
		m.exec (err)->
			return cb err if err
			cache.del gid
			cb undefined, data
			

get_game = exports.get_game = (gid, cb)->
	if _.isString gid
		cb new Error "gid == 'undefined'" if gid is 'undefined'
		
		if data = cache.get gid
			return cb undefined, data
		
		data = 
			status: (m)-> m.hget gid, 'status'
			player_num: (m)-> m.hget gid, 'player_num'
			version: (m)-> m.hget gid, 'version'
			seats: (m)-> m.hget gid, 'seats'
			next: (m)-> m.hget gid, 'next'
			title: (m)-> m.hget gid, 'title'
			init_ts: (m)-> m.hget gid, 'init_ts'
			players: (m)-> multi.smembers [gid, 'players'].join('|')
			moves: (m)-> multi.zrange [gid, 'main'].join('|'), 0, -1
			result: (m)-> m.hget gid, 'result'
			initiator: (m)-> m.hget gid, 'initiator'
			contract: (m)-> m.hget gid, 'contract'
			social: (m)-> m.hget gid, 'social'
			calling_finishing: (m)-> m.hget gid, 'calling_finishing'
			analysis: (m)-> m.hget gid, 'analysis'
		multi = client.multi()
		_.chain(data).values().each (f)-> f multi
		multi.exec (err, replies)->
			return cb err if err
			data = _.chain(data).keys().zip(replies).object().value()
			data.seats = JSON.parse data.seats if data.seats
			data.player_num = Number data.player_num if data.player_num
			data.init_ts = Number data.init_ts if data.init_ts
			data.moves = _.map data.moves, (x)-> JSON.parse x
			data.result = JSON.parse data.result if data.result
			data.contract = JSON.parse data.contract if data.contract
			data.calling_finishing = JSON.parse data.calling_finishing if data.calling_finishing
			data.analysis = JSON.parse data.analysis if data.analysis
			cache.set gid, data
			data.id = gid
			return cb new Error "#{gid} not exists" if not data.status or not data.version
			cb undefined, data
	else if _.isArray gid
		async.map gid, ((x, cb)->get_game x, cb), cb
	else
		cb new Error "unknown gid #{gid}"

player_attend = exports.player_attend = (gid, uid, cb)->
	get_game gid, (err, data)->
		return cb err if err
		if data.player_num <= data.players.length
			return cb new Error "player_attend: no available seat for #{gid}"
		if uid in data.players
			return cb new Error "player_attend: #{uid} has already been in #{gid}"
		
		get_user data.initiator, (err, initiator)->
			return cb err if err
			
			if data.status is STATUS.INIT
				multi = client.multi()
				multi.sadd [gid, GAME.PLAYERS].join('|'), uid
				multi.zadd [uid, USER.CURRENT_GAME].join('|'), exports.now(), gid
				if gid is initiator.my_new_game and data.players.length is data.player_num - 1
					multi.hdel data.initiator, 'my_new_game'
					reset_my_new_game = true
				multi.exec (err)->
					return cb err if err
					cache.del gid
					if reset_my_new_game
						cache.del data.initiator
						cache.del data.initiator + '_upds'
					get_game gid, (err, data)->
						return cb err if err
						((uid, data, cb)->
							if uid is data.initiator or (data.contract.players and uid in data.contract.players)
								cb()
							else
								send_post gid, {type:'player_attend', gid:gid, uid:uid}, (err, pid)->
									if err
										cb()
									else
										forward_post uid, null, pid, cb
						) uid, data, ->
							if data.contract.seats and uid in _.values(data.contract.seats)
								taking_seat gid, data.contract.seats, cb
							else if data.players.length >= data.player_num
								taking_seat gid, cb
							else
								cb undefined, false
			else if data.status is STATUS.NEED_PLAYER
				multi = client.multi()
				multi.sadd [gid, GAME.PLAYERS].join('|'), uid
				multi.zadd [uid, USER.CURRENT_GAME].join('|'), exports.now(), gid
				multi.hset gid, GAME.STATUS, STATUS.STARTED
				multi.hset gid, GAME.SEATS, JSON.stringify _.defaults(data.seats, {black:uid, white:uid})
				if gid is initiator.my_new_game and data.players.length is data.player_num - 1
					multi.hdel data.initiator, 'my_new_game'
					reset_my_new_game = true
				multi.exec (err)->
					return cb err if err
					cache.del gid
					if gid is initiator.my_new_game
						cache.del data.initiator
						cache.del data.initiator + '_upds'
					cb?()
			else
				throw new Error "not implement player_attend #{data.status}"

taking_seat = exports.taking_seat = ->
	switch arguments.length
		when 2
			[gid, cb] = arguments
			client.hset gid, 'status', STATUS.TAKING_SEAT, (err)->
				if err
					cb err
				else
					cache.del gid
					cb undefined, true
		when 3
			[gid, user_decision, cb] = arguments # user_decision = black:some_uid
			get_game gid, (err, data)->
				return cb err if err
				
				if not (data.status in [STATUS.INIT, STATUS.TAKING_SEAT])
					return cb new Error "taking_seat: #{gid} status #{data.status}"
				if not _.chain(user_decision).values().every((x)-> x in data.players).value()
					return cb new Error "taking_seat: some of [#{_.values(user_decision).join(', ')}] not in the game #{gid}"
				data.seats = if data.seats
					_.chain(data.seats).invert().extend(_.invert user_decision).invert().value()
				else
					user_decision
				m = client.multi()
				m.hset gid, 'seats', JSON.stringify(data.seats)
				m.hset gid, 'status', STATUS.TAKING_SEAT
				m.exec (err)->
					return cb err if err
					cache.del gid
					all_arrived = _.keys(data.seats).length is data.player_num
					if all_arrived and data.contract.start is 'auto'
						start_game gid, cb
					else
						cb undefined, data.seats, all_arrived


start_game = exports.start_game = (gid, cb)->
	get_game gid, (err, data)->
		return cb? err if err
		if data.status in [STATUS.INIT, STATUS.STARTED]
			return cb new Error "start_game: fail to start #{gid} in status #{data.status}"
		if data.status is STATUS.TAKING_SEAT
			if not data.seats or data.player_num > _.keys(data.seats).length
				return cb new Error "start_game: please taking seat in #{gid}"
			
		get_user data.players, (err, users)->
			return cb? err if err
			
			m = client.multi()
			m.hset gid, 'status', STATUS.STARTED
			m.hset gid, 'next', 'black'
			m.zadd 'weiqi_games', 0, gid
			_.chain(users).values().each (u)->
				m.hdel u.id, 'my_new_game' if u.my_new_game
			
			if data.contract.moves?.length
				_.each data.contract.moves, (x, i)->
					x.n = i
					m.zadd [gid, 'main'].join('|'), x.n, JSON.stringify(x)
			
			m.exec (err)->
				cache.del gid
				cb err

surrender = exports.surrender = (gid, uid, cb)->
	get_game gid, (err, data)->
		return cb? err if err
		if data.status isnt STATUS.STARTED
			return cb? new Error "surrender: fail for #{uid} as #{gid} is in #{data.status}"
		if not (uid in data.players)
			return cb? new Error "surrender: #{uid} is not in #{gid}"
		rlt =
			gid: gid
			players: data.seats
			win: _.chain(data.seats).pairs().reject((x)-> x[1] is uid).value()[0][0]
			case: _.invert(data.seats)[uid] + ' surrenders'
			moves: data.moves?.length
			ts: exports.now()
		
		m = client.multi()
		m.hset gid, 'result', JSON.stringify(rlt)
		m.hset gid, 'status', STATUS.ENDED
		_.each data.players, (x)->
			m.zrem [x, USER.CURRENT_GAME].join('|'), gid
			m.zadd [x, USER.HISTORY].join('|'), exports.now(), gid
		m.exec (err)->
			cache.del gid
			if err
				cb? err
			else
				cb? undefined, rlt
		
end_game = exports.end_game = (gid, counting, cb)->
	get_game gid, (err, data)->
		return cb? err if err
		if data.status isnt STATUS.STARTED
			return cb? new Error "surrender: #{gid} is in #{data.status}"

		diff = counting.black - counting.white
		rlt = \
		if diff > 0
			win:  'black'
			case: "black win #{diff}#{counting.unit}"
		else if diff < 0
			win:  'white'
			case: "white win #{-diff}#{counting.unit}"
		else
			draw: true
		_.defaults rlt, 
			players: data.seats
			moves: data.moves?.length
			gid: gid
			
		m = client.multi()
		m.hset gid, 'result', JSON.stringify(rlt)
		m.hset gid, 'status', STATUS.ENDED
		m.exec (err)->
			cache.del gid
			if err
				cb? err
			else
				cb? undefined, rlt

discard_game = exports.discard_game = (gid, cb)->
	get_game gid, (err, data)->
		return cb err if err
		get_user data.initiator, (err, user)->
			m = client.multi()
			_.each [
				gid
				[gid, GAME.MOVES].join('|')
				[gid, GAME.PLAYERS].join('|')
				[gid, GAME.PLAYERS_QUIT].join('|')
				[gid, GAME.MY_BLOGS].join('|')
				[gid, GAME.BLOGS].join('|')
				[gid, GAME.BLOG_COUNT].join('|')
				[gid, GAME.BLOG_CACHE].join('|')
			], (x)-> m.del x
			_.each data.players, (x)-> m.zrem [x, USER.CURRENT_GAME].join('|'), gid
			m.hdel user?.id, 'my_new_game' if gid is user?.my_new_game
			m.exec (err)->
				return cb err if err
				cache.del gid
				remove_comments gid, cb

player_quit = exports.player_quit = (gid, uid, cb)->
	get_game gid, (err, data)->
		return cb err if err
		if uid in data.players
			cb = _.wrap cb, (cb, err)->
				if err
					cb err
				else if data.social
					send_post gid, {type:'player_quit', gid:gid, player:uid}, (err, pid)-> cb()
				else
					cb()
			
			if data.status is STATUS.INIT
				if data.players.length is 1
					discard_game gid, cb
				else
					client.srem [gid, 'players'].join('|'), uid, (err)->
						cache.del gid
						cb err
			else if data.status is STATUS.TAKING_SEAT
				multi = client.multi()
				multi.srem [gid, 'players'].join('|'), uid
				multi.hset gid, 'status', STATUS.INIT
				if data.seats
					multi.hset gid, 'seats', JSON.stringify _.chain(data.seats).invert().omit(uid).invert().value()
				multi.exec (err)->
					return cb err if err
					cache.del gid
					cb()
			else
				multi = client.multi()
				multi.srem [gid, 'players'].join('|'), uid
				multi.hset gid, 'status', STATUS.NEED_PLAYER
				multi.hset gid, 'seats', JSON.stringify _.chain(data.seats).invert().omit(uid).invert().value()
				multi.zrem [uid, 'weiqi'].join('|'), gid
				multi.exec (err)->
					return cb err if err
					cache.del gid
					cb()
		else
			cb new Error "#{uid} is not on #{gid}"

update_game = exports.update_game = (gid, move, cb)->
	client.zadd [gid, 'moves'].join('|'), exports.now(), JSON.stringify(move), cb

read_game = exports.read_game = ->
	switch arguments.length
		when 2
			[gid, cb] = arguments
	
	client.zrange [gid, 'moves'].join('|'), 0, -1, (err, replies)->
		return cb err if err
		cb undefined, _.map(replies, (x)-> JSON.parse x)


connect = exports.connect = (uid, gid, cb)->
	get_user uid, (err, user)->
		return cb? err if err
		if user.connect?
			expired = _.chain(user.connect).pairs().filter((x)-> x[1] < SERVER_STARTED).pluck(0).value()
			if expired.length
				_.each expired, (x)-> delete user.connect[x]
			else if user.connect?[gid]
				return cb?() 
		
		get_game gid, (err, data)->
			return cb? err if err
			return cb?() if data.players and not uid in data.players
			
			user.connect?= {}
			user.connect[gid] = new Date().getTime()
			multi = client.multi()
			multi.hset uid, 'connect', JSON.stringify(user.connect)
			multi.exec (err)->
				return cb? err if err
				cache.del uid
				cb?()

disconnect = exports.disconnect = (uid, gid, cb)->
	get_user uid, (err, user)->
		return cb? err if err
		if user.connect?[gid]
			delete user.connect[gid]
			multi = client.multi()
			multi.hset uid, 'connect', JSON.stringify(user.connect)
			multi.exec (err)->
				return cb? err if err
				cache.del uid
				cb?()
		else
			cb?()

is_game_alive = exports.is_game_alive = (gid, cb)->
	get_game gid, (err, data)->
		return cb err if err
		return cb undefined, false if data.status isnt STATUS.STARTED
		return cb undefined, false if not data.players?.length or data.players?.length < data.player_num
		
		get_user data.players, (err, users)->
			return cb err if err
			cb undefined, _.every users, (x)-> x?.connect?[gid] > SERVER_STARTED

live_show_mark = exports.live_show_mark = (gid, cb)-> cb undefined, 100

add_live_show = exports.add_live_show = (gid, cb)->
	is_game_alive gid, (err, alive)->
		return cb err, alive if err or not alive
		live_show_mark gid, (err, mark)->
			return cb err if err
			client.zadd LIVE_SHOW, mark, gid, cb

remove_live_show = exports.remove_live_show = (gid, cb)->
	is_game_alive gid, (err, alive)->
		if err or alive
			cb()
		else
			client.zrem LIVE_SHOW, gid, cb

fetch_live_shows = exports.fetch_live_shows = ->
	switch arguments.length
		when 2
			[loginUser, cb] = arguments
		when 1
			[cb] = arguments
	
	client.zrange LIVE_SHOW, 0, -1, cb

add_comment = exports.add_comment = (gid, comment, cb)->
	comment.gid = gid
	get_game gid, (err, game)->
		return cb err if err
		comment.type = 'game_comment'
		send_post gid, comment, (err, pid)->
			return cb err if err
			if comment.step?
				m = client.multi()
				m.sadd [gid, COMMENTS].join('|'), comment.step
				m.zadd [gid, COMMENTS, comment.step].join('|'), exports.now(), pid
				if comment.author in game.players
					m.sadd [gid, COMMENTS_PLAYERS].join('|'), comment.step
					m.zadd [gid, COMMENTS_PLAYERS, comment.step].join('|'), exports.now(), pid
				m.exec (err)->
					return cb err if err
					forward_post comment.author, null, pid, (err)-> cb undefined, pid
			else
				cb undefined, pid

get_comments = exports.get_comments = (gid, cb)->
	switch arguments.length
		when 2
			[gid, cb] = arguments
			info =
				comments: (m)->m.smembers [gid, COMMENTS].join('|')
				comments_players: (m)->m.smembers [gid, COMMENTS_PLAYERS].join('|')
			m = client.multi()
			_.chain(info).values().each (x)-> x m
			m.exec (err, replies)->
				return cb err if err
				cb undefined, _.chain(info).keys().zip(replies).object().value()
		when 3
			[gid, tag, cb] = arguments
			get_comments gid, tag, 5, cb
		when 4
			[gid, tag, num, cb] = arguments
			return cb new Error "get_comments: unknown tag #{tag}" if not (tag in [COMMENTS, COMMENTS_PLAYERS])
			client.smembers [gid, tag].join('|'), (err, replies)->
				return cb err if err
				m = client.multi()
				_.each replies, (x)-> m.zrevrange [gid, tag, x].join('|'), 0, num-1
				m.exec (err, replies)->
					return cb err if err
					return cb undefined, [] if not replies.length
					m = client.multi()
					_.chain(replies).flatten().each (x)-> m.get x
					m.exec (err, replies)->
						return cb err if err
						cb undefined, _.chain(replies).map((x)-> JSON.parse x).groupBy((x)->x.step).value()
		when 6
			[gid, tag, step, start, num, cb] = arguments
			client.zrevrange [gid, tag, step].join('|'), start-1, start + num-2, (err, reply)->
				return cb err if err
				m = client.multi()
				_.each reply, (x)-> m.get x
				m.exec (err, replies)->
					return cb err if err
					cb undefined, _.chain(replies).map((x)-> JSON.parse x).groupBy((x)->x.step).value()
		else
			cb new Error "get_comments: unknown arguments"
				

remove_comments = (gid, cb)->
	get_comments gid, (err, data)->
		return cb err if err
		multi = client.multi()
		_.chain(data).pairs().each (x)->
			multi.del [gid, x[0]].join('|')
			_.each x[1], (y)-> multi.del [gid, x[0], y].join('|')
		multi.exec cb

follow = exports.follow = (uid, followed_uid, cb)->
	return cb new Error "#{uid} cannot follow #{followed_uid} itself!" if uid is followed_uid
	m = client.multi()
	m.sismember [uid, RELATED.FOLLOWED].join('|'), followed_uid
	m.sismember [uid, RELATED.FRIENDS].join('|'), followed_uid
	m.sismember [followed_uid, RELATED.FOLLOWED].join('|'), uid
	m.sismember [followed_uid, RELATED.FRIENDS].join('|'), uid
	m.exec (err, replies)->
		return cb err if err
		if replies[0]
			return cb undefined, RELATED.FOLLOWED
		if replies[1]
			return cb undefined, RELATED.FRIENDS
		m = client.multi()
		fid = ['pf',uid, followed_uid].join('|')
		if replies[2] or replies[3] # become friends
			m.sadd [uid, RELATED.FRIENDS].join('|'), followed_uid
			m.srem [followed_uid, RELATED.FOLLOWED].join('|'), uid
			m.sadd [followed_uid, RELATED.FRIENDS].join('|'), uid
			send_post m, uid, fid, {type:'friends', A: uid, B: followed_uid}
			rlt = RELATED.FRIENDS
		else # just followed
			m.sadd [uid, RELATED.FOLLOWED].join('|'), followed_uid
			send_post m, uid, fid, {type:'followed', A: uid, B: followed_uid}
			rlt = RELATED.FOLLOWED
		m.sadd [followed_uid, RELATED.FOLLOWING].join('|'), uid
		m.zadd [uid, USER.EVENT_FOLLOW].join('|'), exports.now(), JSON.stringify {followed:followed_uid, ts: exports.now()}
		notify_post m, followed_uid, fid
		m.exec (err)->
			if err
				cb? err
			else
				cb undefined, rlt

unfollow = exports.unfollow = (uid, followed_uid, cb)->
	client.sismember [followed_uid, 'friends'].join('|'), uid, (err, were_friends)->
		return cb err if err
		m = client.multi()
		if were_friends
			m.srem [followed_uid, RELATED.FRIENDS].join('|'), uid
			m.add [followed_uid, RELATED.FOLLOWED].join('|'), uid
		m.srem [followed_uid, RELATED.FOLLOWING].join('|'), uid
		m.srem [uid, RELATED.FOLLOWED].join('|'), followed_uid
		m.srem [uid, RELATED.FRIENDS].join('|'), followed_uid
		remove_blog_cache m, uid
		m.exec cb

follow_game = exports.follow_game = (uid, gid, cb)->
	m = client.multi()
	m.sadd [uid, USER.FOLLOWED_GAMES].join('|'), gid
	m.exec cb
	
unfollow_game = exports.unfollow_game = (uid, gid, cb)->
	m = client.multi()
	m.srem [uid, USER.FOLLOWED_GAMES].join('|'), gid
	remove_blog_cache m, uid
	m.exec cb

remove_blog_cache = (m, uid)->
	m.del [uid, USER.BLOGS].join('|')
	m.del [uid, USER.CURRENT_PAGE].join('|')
	m.del [uid, USER.BLOG_CACHE].join('|')
	

get_related = exports.get_related = (uid, types, cb)->
	types = [types] if _.isString types
	m = client.multi()
	_.each types, (x)-> m.smembers [uid, x].join('|')
	m.exec (err, replies)->
		return cb err if err
		cb? undefined, _.chain(types).zip(replies).object().value()


f_invite_id = (sender, receiver)-> ['invite', sender, receiver].join('|')

invite = exports.invite = ->
	switch arguments.length
		when 3
			[sender, receiver, cb] = arguments
			invite sender, receiver, {}, cb
		when 4
			[sender, receiver, opts, cb] = arguments
			if sender is receiver
				return cb new Error "invite: #{sender} invite #{receiver}"
			get_user [sender, receiver], (err, users)->
				return cb err if err
				return cb new Error "invite: #{sender} not found" if not users[sender]
				return cb new Error "invite: #{receiver} not found" if not users[receiver]
				data =
					v: .1
					id: f_invite_id sender, receiver
					sender: sender
					receiver: receiver
					ts: exports.now()
				data = _.defaults data, opts
				data.expire ?= 7 * 24 * 60 * 60
				m = client.multi()
				m.set data.id, JSON.stringify(data)
				m.zadd [sender, USER.INVITING].join('|'), exports.now(), receiver
				m.zadd [receiver, USER.INVITED].join('|'), (users[sender].rate ? 0) + (data.money ? 0), sender
				m.exec (err)->
					if err
						cb err
					else
						cb undefined, data.id

cancel_invite = exports.cancel_invite = ->
	switch arguments.length
		when 2
			if _.isString arguments[0]
				[invite_id, cb] = arguments
				client.get invite_id, (err, data)->
					return cb err if err
					return cb new Error "take_invitation: not found #{invite_id}" if not data
					data = JSON.parse data
					m = client.multi()
					m.del invite_id
					m.zrem [data.sender, USER.INVITING].join('|'), data.receiver
					m.zrem [data.receiver, USER.INVITED].join('|'), data.sender
					cache.del "#{data.sender}_sent_invite"
					cache.del "#{data.receiver}_received_invite"
					m.exec cb
			else if _.isArray arguments[0]
				[invites, cb] = arguments
				return cb?() if not invites.length
				m = client.multi()
				_.each invites, (x)->
					m.del x.id
					m.zrem [x.sender, USER.INVITING].join('|'), x.receiver
					m.zrem [x.receiver, USER.INVITED].join('|'), x.sender
					cache.del "#{x.sender}_sent_invite"
					cache.del "#{x.receiver}_received_invite"
					m.exec cb
					
		when 3
			[sender, receiver, cb] = arguments
			cancel_invite f_invite_id(sender, receiver), cb
			
get_invitation = exports.get_invitation = ->
	switch arguments.length
		when 2
			if _.isArray arguments[0]
				[ids, cb] = arguments
				m = client.multi()
				_.each ids, (x)-> m.get x
				m.exec (err, replies)->
					return cb err if err
					invites = _.chain(replies).compact().map((x)->JSON.parse x).value()
					cancel_invite _.reject(invites, (x)-> x.ts + x.expire > exports.now()), ->
					cb undefined, _.filter(invites, (x)-> x.ts + x.expire > exports.now())
			else if _.isString arguments[0]
				[id, cb] = arguments
				get_invitation [id], (err, invitation)->
					cb err, invitation[0]
		when 3
			[sender, receiver, cb] = arguments
			get_invitation f_invite_id(sender, receiver), cb
			
get_sent_invitation = exports.get_sent_invitation = (uid, cb)->
	invitaion = cache.get cid = "#{uid}_sent_invite"
	return cb undefined, invitaion if invitaion
	
	client.zrange [uid, USER.INVITING].join('|'), 0, -1, (err, ids)->
		return cb err if err
		return cb undefined, [] if not ids.length
		get_invitation _.map(ids, (x)->
			f_invite_id(uid, x)
		), (err, invitaion)->
			if err
				cb err
			else
				cache.set cid, invitaion
				cb undefined, invitaion

get_received_invitation = exports.get_received_invitation = ->
	switch arguments.length
		when 2
			[uid, cb] = arguments
			get_received_invitation uid, 20, cb
		when 3
			[uid, num, cb] = arguments
			invitaion = cache.get cid = "#{uid}_received_invite"
			return cb undefined, invitaion if invitaion
			client.zrevrange [uid, USER.INVITED].join('|'), 0, num, (err, ids)->
				return cb err if err
				return cb undefined, [] if not ids.length
				get_invitation _.map(ids, (x)->
					f_invite_id(x, uid)
				), (err, invitaion)->
					if err
						cb err
					else
						cache.set cid, invitaion
						cb undefined, invitaion

take_invitation = exports.take_invitation = ->
	switch arguments.length
		when 2
			[invite_id, cb] = arguments
			get_invitation invite_id, (err, invitation)->
				return cb err if err
				return cb new Error "take_invitation: not found #{invite_id}" if not invitation
				
				opts = 
					initiator: invitation.sender
					type: 'weiqi'
					invitation: invitation
					players: [invitation.sender, invitation.receiver]
					start: 'auto'
					seats: invitation.seats
					contract:
						invite: invitation
				init_game opts, (err, gid)->
					return cb err if err
					m = client.multi()
					m.del invite_id
					m.zrem [invitation.sender, USER.INVITING].join('|'), invite_id
					m.zrem [invitation.receiver, USER.INVITED].join('|'), invite_id
					m.exec (err)->
						return cb err if err
						cache.del "#{invitation.sender}_sent_invite"
						cache.del "#{invitation.receiver}_received_invite"
						cb undefined, gid
		when 3
			[sender, receiver, cb] = arguments
			take_invitation f_invite_id(sender, receiver), cb
			
game_rating = exports.game_rating = (game_result, cb)->
	get_user _.values(game_result.players), (err, users)->
		prev_rates = _.chain(users).pairs().map((x)->[x[0], x[1].rate]).object().value()
		users = _.map ['black', 'white'], (x)->
			u = users[game_result.players[x]]
			u.rate ?= 1500
			u
		rating.elo_rating users, game_result
		m = client.multi()
		_.each users, (x)-> 
			m.hset x.id, 'rate', x.rate
			title = _.find(rating.config.levels, (y)-> y.min <= x.rate <= y.max).title
			if title_changed = title isnt x.title
				m.hset x.id, 'title', title
				x.title = title
			m.zadd [x.id, USER.RECORDS].join('|'), exports.now(), JSON.stringify(gid:game_result.gid, rate: x.rate, prev_rate: prev_rates[x.id], title_changed:title_changed)
			m.incr [x.id, USER.TOTAL_GAMES].join('|')
			if game_result.draw
				m.incr [x.id, USER.DRAWS].join('|')
			else if game_result.win
				if game_result.players[game_result.win] is x.id
					m.incr [x.id, USER.WINS].join('|')
				else
					m.incr [x.id, USER.LOSSES].join('|')
		m.exec (err)->
			return cb err if err
			_.each users, (x)-> cache.del x.id
			get_user _.pluck(users, 'id'), (err, users)->
				return cb err if err
				cb undefined, _.chain(['black', 'white']).zip(_.values users).object().value()

create_group = exports.create_group = (opts, cb)->
	return cb new Error "create_group: no managers" if not opts.managers
	client.incr 'group:id', (err, id)->
		return cb? err if err
		id = 'group' + id
		m = client.multi()
		_.each 'name'.split(' '), (x)->
			m.hset id, x, opts[x]
		_.each opts.managers, (x)->
			m.sadd [id, 'members'].join('|'), x
		m.exec (err)->
			if err
				cb err
			else
				cb undefined, id

join_group = exports.join_group = (uid, gid, cb)->
	m = client.multi()
	m.sadd [gid, 'members'].join('|'), uid
	m.exec cb

quit_group = exports.quit_group = (uid, gid, cb)->
	m = client.multi()
	m.srem [gid, 'members'].join('|'), uid
	m.exec cb

get_group = exports.get_group = (gid, cb)->
	group =
		name: (m)-> m.hget gid, 'name'
		members: (m)-> m.smembers [gid, 'members'].join('|')
	m = client.multi()
	_.chain(group).values().each (fn)-> fn m
	m.exec (err, replies)->
		return cb err if err
		cb undefined, _.chain(group).keys().zip(replies).object().value()

get_blogs = exports.get_blogs = ->
	switch arguments.length
		when 2
			if _.isString arguments[0]
				[uid, cb] = arguments
				get_blogs uid, USER.MY_BLOGS, 0, 10, cb
			else
				[blogs, cb] = arguments
				cached_blogs = _.chain(blogs).map((x)-> [x, cache.get x]).object().value()
				non_cached_blogs = _.chain(cached_blogs).keys().reject((x)->cached_blogs[x]).value()
				if not non_cached_blogs.length
					return cb undefined, _.values(cached_blogs)
				
				m = client.multi()
				_.each non_cached_blogs, (x)-> m.get x
				m.exec (err, replies)->
					return cb err if err
					
					_.chain(replies).map((x)-> JSON.parse x).zip(non_cached_blogs).each (x)->
						if x[0]
							x[0].id = x[1]
							cached_blogs[x[1]] = x[0]
					blogs = _.chain(cached_blogs).values().compact().value()
					
					forwardings = _.chain(blogs).where(type:'forward').filter((x)->x.original and not x.original_blog).reject((x)->
						x.original_blog = cache.get x.original
					).value()
					((forwardings, cb)->
						if forwardings.length
							m = client.multi()
							_.each forwardings, (x)-> m.get x.original
							m.exec (err, replies)->
								return cb err if err
								_.chain(forwardings).zip(replies).each (x)->
									if x[1]
										x[0].original_blog = JSON.parse x[1]
								cb()
						else
							cb()
					) forwardings, (err)->
						_.each blogs, (x)-> cache.set x.id, x if x
						cb undefined, blogs
		when 3
			[uid, tag, cb] = arguments
			get_blogs uid, tag, 0, 10, cb
		when 5
			[uid, tag, start, count, cb] = arguments
			fn = (err, blogs)->
				return cb err if err
				return cb undefined, [] if not blogs.length
				get_blogs blogs, cb
			switch tag
				when USER.BLOGS
					client.zrevrange [uid, USER.BLOGS].join('|'), start, start + count, fn
				when USER.MY_BLOGS
					client.zrevrange [uid, USER.MY_BLOGS].join('|'), start, start + count, fn
				else
					cb new Error "get_blogs: unknown tag #{tag}"

send_post = exports.send_post = ->
	switch arguments.length
		when 4
			[m, uid, post_id, post] = arguments
			m.set post_id, JSON.stringify(post)
			#m.expire post_id, BLOG_EXPIRATION
			#m.zadd [uid, USER.BLOGS].join('|'), exports.now(), post_id
			m.zadd [uid, USER.MY_BLOGS].join('|'), exports.now(), post_id
		when 3
			[uid, post, cb] = arguments
			post.ts = exports.now()
			post.author = uid if not post.author and not post.gid
			client.incr [uid, USER.BLOG_COUNT].join('|'), (err, count)->
				return cb err if err
				m = client.multi()
				pid = [uid, 'p' + count].join('|')
				send_post m, uid, pid, post
				m.exec (err)->
					if err
						cb err
					else
						cb undefined, pid

send_post_tpl = exports.send_post_tpl = ->
	[type, scenario] = arguments
	switch type
		when 'init_game'
			switch scenario
				when 'init_and_wait'
					[gid, initiator, cb] = _.toArray(arguments)[2..]
					get_user initiator, (err, initiator)->
						return cb err if err
						send_post gid, {
							type:'init_game'
							scenario:scenario
							v: .1
							gid:gid
							initiator: _.pick initiator, ['id', USER.WINS, USER.LOSSES, USER.TOTAL_GAMES, 'win_ratio', 'rate']
						}, cb
				when 'init_and_start'
					[gid, players, cb] = _.toArray(arguments)[2..]
					get_user players, (err, players)->
						return cb err if err
						send_post gid, {
							type:'init_game'
							scenario:scenario
							v: .1
							gid:gid
							players: _.chain(players).values().map((x)-> _.pick x, ['id', USER.WINS, USER.LOSSES, USER.TOTAL_GAMES, 'win_ratio', 'rate']).value()
						}, cb
				else
					[gid, cb] = _.toArray(arguments)[2..]
					send_post gid, {type:'init_game', gid:gid}, cb

delete_post = exports.delete_post = (post_id, cb)->
	get_blogs [post_id], (err, posts)->
		return cb err if err
		return cb() if not posts.length
		m = client.multi()
		m.del post_id
		if posts[0].author
			m.zrem [posts[0].author, USER.MY_BLOGS].join('|'), post_id
			m.zrem [posts[0].author, USER.BLOGS].join('|'), post_id
		m.exec (err)->
			if err
				cb err
			else
				cache.del post_id
				cb()
	
notify_post = (m, uid, post_id)->
	m.zadd [uid, USER.NOTICE].join('|'), exports.now(), post_id

forward_post = exports.forward_post = (uid, my_comment, forwareded_pid, cb)->
	get_blogs [forwareded_pid], (err, fp)->
		return cb err if err
		[fp] = fp
		if fp.type is 'forward'
			post = 
				type: 'forward'
				original: fp.original
				comment: my_comment
				author: uid
			post.comment = my_comment + "//@{#{fp.author}}: " + fp.comment
		else
			post = 
				type: 'forward'
				original: forwareded_pid
				comment: my_comment
				author: uid
		send_post uid, post, cb
			
fetch_blogs = exports.fetch_blogs = ->
	switch arguments.length
		when 4
			[uid, from_time, count, cb] = arguments
			uid_set = if _.isString(uid) then [uid] else uid
			m = client.multi()
			_.each uid_set, (x)-> m.zrevrangebyscore [[x, USER.MY_BLOGS].join('|'), from_time, '-inf', 'WITHSCORES', 'LIMIT', 0, count]
			m.exec (err, replies)->
				return cb err if err
				replies = _.map replies, (x)->
					_.chain(x).groupBy((y, i)-> Math.floor i/2).toArray().value()
				blogs = _.chain(uid_set).zip(replies).object().value()
				cb undefined, if _.isString(uid) then blogs[uid] else blogs
		when 5
			[uid, uid_set, from_time, count, cb] = arguments
			m = client.multi()
			_.each uid_set, (x)-> m.zrevrangebyscore [[x, USER.MY_BLOGS].join('|'), from_time, '-inf', 'WITHSCORES', 'LIMIT', 0, count]
			m.zrevrangebyscore [[uid, USER.NOTICE].join('|'), from_time, '-inf', 'WITHSCORES', 'LIMIT', 0, count]
			m.exec (err, replies)->
				return cb err if err
				replies = _.map replies, (x)->
					_.chain(x).groupBy((y, i)-> Math.floor i/2).toArray().value()
				uid_set.push 'notice'
				blogs = _.chain(uid_set).zip(replies).object().value()
				blogs[uid] = if blogs[uid]
						_.chain([blogs[uid], blogs.notice]).flatten(true).sortBy((x)-> -x[1]).value()
					else
						blogs.notice
				delete blogs.notice
				cb undefined, blogs
				
get_page = exports.get_page = ->
	switch arguments.length
		when 2
			[uid, cb] = arguments
			get_page uid, 'recent', cb
		when 3
			[uid, tag, cb] = arguments
			window = 60 * 60 * 24
			m = client.multi()
			m.get [uid, USER.BLOG_CACHE].join('|')
			m.smembers [uid, RELATED.FOLLOWED].join('|')
			m.smembers [uid, RELATED.FRIENDS].join('|')
			m.smembers [uid, USER.FOLLOWED_GAMES].join('|')
			m.get [uid, USER.CURRENT_PAGE].join('|')
			m.exec (err, replies)->
				blog_cache = if replies[0] then JSON.parse replies[0] else []
				followed = _.flatten [replies[1], replies[2], replies[3], uid]
				current_page = replies[4]
				return cb() if not followed.length
				switch tag
					when 'next'
						return get_page uid, 'recent', cb if not current_page
						get_blogs uid, USER.BLOGS, BLOGS_IN_PAGE*current_page, BLOGS_IN_PAGE, (err, blogs)->
							return cb err if err
							if not blogs.length
								return cb undefined, []
							else if blogs.length < BLOGS_IN_PAGE
								fetch_blogs uid, followed, blog_cache[blog_cache.length-1][0], 10, (err, blogs)->
									return cb err if err
									blog_cache[blog_cache.length-1][0] = Number _.chain(blogs).values().flatten(true).pluck(1).min().value() ? 0
									m = client.multi()
									m.set [uid, USER.BLOG_CACHE].join('|'), JSON.stringify(blog_cache)
									m.incr [uid, USER.CURRENT_PAGE].join('|')
									_.chain(blogs).values().flatten(true).each (x)-> m.zadd [uid, USER.BLOGS].join('|'), x[1], x[0]
									m.exec (err)->
										return cb err if err
										get_blogs uid, USER.BLOGS, BLOGS_IN_PAGE*current_page, BLOGS_IN_PAGE, (err, blogs)->
											return cb err if err
											cb undefined, blogs, blog_cache, Number(current_page) + 1
							else
								client.incr [uid, USER.CURRENT_PAGE].join('|'), (err)->
									return cb err if err
									cb undefined, blogs, blog_cache, Number(current_page) + 1
								
					when 'recent'
						time = exports.now()
						fetch_blogs uid, followed, time, 10, (err, blogs)->
							return cb err if err
							min_time = _.chain(blogs).values().flatten(true).pluck(1).min().value() ? 0
							if blog_cache.length
								last = blog_cache.pop()
								if last[0] <= min_time <= last[1]
									last[1] = time
									blog_cache.push last
								else
									blog_cache.push last
									blog_cache.push [Number(min_time), time]
							else
								blog_cache.push [Number(min_time), time]
								
							m = client.multi()
							m.set [uid, USER.BLOG_CACHE].join('|'), JSON.stringify(blog_cache)
							m.set [uid, USER.CURRENT_PAGE].join('|'), current_page = 1
							_.chain(blogs).values().flatten(true).each (x)-> m.zadd [uid, USER.BLOGS].join('|'), x[1], x[0]
							m.exec (err)->
								return cb err if err
								get_blogs uid, USER.BLOGS, 0, BLOGS_IN_PAGE, (err, blogs)->
									return cb err if err
									cb undefined, blogs, blog_cache, 1
					else
						cb new Error "get_page: unknown tag #{tag}"

users_in_comment = exports.users_in_comment = (comment)->
	return null if not comment
	tmp = []
	p = /@\{(\w+\d+)\}/g
	while m = p.exec comment
		tmp.push m[1]
	if tmp.length then tmp else null

get_refs = exports.get_refs = (data, cb)->
	get_game _.chain(data.blogs).pluck('gid').union(data.games).flatten().uniq().compact().value(), (err, games)->
		return cb err if err
		games = _.compact games
		
		refs = _.chain(games).map((x)->[x.id, x]).object().value()
		get_user _.chain([
			_.map data.blogs, (x)-> [x.author, x.original_blog?.author, users_in_comment(x.comment)]
			_.map games, (x)-> [x.initiator, x.players]
			data.users
		]).flatten().uniq().compact().value(), (err, users)->
			refs = _.defaults refs, users
			_.chain(refs).keys().each (x)-> delete refs[x] if not refs[x]
			cb undefined, refs

retract = exports.retract = (uid, gid, cb)->
	get_game gid, (err, game)->
		return cb err if err
		
		if game.moves.length and game.seats[game.moves[game.moves.length-1].player] is uid
			m = client.multi()
			m.zremrangebyrank [gid, 'main'].join('|'), -1, -1
			m.hset gid, 'next', game.moves[game.moves.length-1].player
			_.chain(game.moves).where(repealed: game.moves.length-1).each (x)->
				delete x.repealed
				m.ZREMRANGEBYSCORE [gid, 'main'].join('|'), x.n, x.n
				m.zadd [gid, 'main'].join('|'), x.n, JSON.stringify(x)
			m.exec (err)->
				if err
					cb err
				else
					cache.del gid
					cb()
		else
			cb new Error "retract: #{uid} failed in #{gid}"

call_finishing = exports.call_finishing = (gid, uid, msg, cb)->
	get_game gid, (err, game)->
		return cb err if err
		return cb new Error "#{uid} is not a player in #{gid}" if not (uid in game.players)
		switch msg
			when 'ask'
				client.hset gid, 'calling_finishing', JSON.stringify(uid:uid, msg:msg), (err)->
					return cb err if err
					cache.del gid
					cb()
			when 'cancel', 'stop'
				client.hdel gid, 'calling_finishing', (err)->
					return cb err if err
					cache.del gid
					cb()
			when 'accept'
				return cb new Error 'no asking' if not game.calling_finishing
				return cb new Error 'the same user' if game.calling_finishing.uid is uid
				client.hset gid, 'calling_finishing', JSON.stringify(uid:uid, msg:msg), (err)->
					return cb err if err
					cache.del gid
					cb()
			when 'reject'
				return cb new Error 'no asking' if not game.calling_finishing
				return cb new Error 'the same user' if game.calling_finishing.uid is uid
				client.hset gid, 'calling_finishing', JSON.stringify(uid:uid, msg:msg), (err)->
					return cb err if err
					cache.del gid
					cb()

analyze = exports.analyze = ->
	switch arguments.length
		when 2
			[gid, cb] = arguments
			analyze gid, false, cb
		when 3
			[gid, save, cb] = arguments
			get_game gid, (err, game)->
				return cb err if err
				analysis = rule.analyze game.moves
				analysis = _.map analysis, (r)->
					r.domains = _.map r.domains, (d)-> 
						#d.liberty_blocks = _.map d.liberty_blocks, (lb)-> _.omit lb, 'stone_blocks'
						d.stone_blocks = _.map d.stone_blocks, (sb)-> _.omit sb, 'opposite', 'liberty', 'liberty_blocks', 'liberty_blocks_owned'
						_.omit d, 'liberty_blocks_peripheral', 'adjacent_domains', 'liberty_blocks'
					r.liberty_blocks = _.map r.liberty_blocks, (lb)-> _.omit lb, 'stone_blocks'
					r = _.omit r, 'adjacent_regiments'
				((save, cb)->
					if save
						client.hset gid, 'analysis', JSON.stringify(analysis), (err)->
							cache.del gid if not err
							cb err
					else
						cb()
				) save, (err)->
					if err
						cb err
					else
						cb undefined, analysis

suggest_finishing = exports.suggest_finishing = ->
	find_disagree = (analysis)->
		_.chain(analysis).filter((r)->
				r.judge is 'disagree'
			).map((r)->
				r.domains[0].stone_blocks[0].block[0].n
			).value()
	switch arguments.length
		when 3
			[gid, uid, cb] = arguments
			get_game gid, (err, game)->
				return cb err if err
				return cb new Error "suggest_finishing: no analysis for #{gid}" if not game.analysis
				return cb new Error "suggest_finishing: #{uid} is not in {gid}" if not (uid in game.players)
				return cb new Error "suggest_finishing: unknown error" if game.players.length isnt 2
				
				if find_disagree(game.analysis).length
					return cb new Error "disagreement in #{gid}"
				
				game.analysis[0].agree ?= []
				game.analysis[0].agree.push uid if not (uid in game.analysis[0].agree)
				client.hset gid, 'analysis', JSON.stringify(game.analysis), (err)->
					if err
						cb err
					else
						cb undefined, game.analysis[0].agree.length is 2
		when 5
			[gid, uid, stone, suggest, cb] = arguments
			get_game gid, (err, game)->
				return cb err if err
				return cb new Error "suggest_finishing: no analysis for #{gid}" if not game.analysis
				return cb new Error "suggest_finishing: #{uid} is not in {gid}" if not (uid in game.players)
				return cb new Error "suggest_finishing: unknown error" if game.players.length isnt 2
				
				m = client.multi()
				regiment = rule.find_regiment game.analysis, stone
				return cb new Error "suggest_finishing: not find stone #{stone} in #{gid}" if not regiment
				regiment.suggets ?= {}
				regiment.suggets[uid] = suggest
				if _.chain(game.players).map((p)->regiment.suggets[p]).compact().uniq().value().length is 2
					regiment.judge = 'disagree'
					game.analysis[0].agree = null
				else
					if suggest isnt (regiment.judge or regiment.guess)
						game.analysis[0].agree = null
					regiment.judge = suggest
				m.hset gid, 'analysis', JSON.stringify(game.analysis)
				m.exec (err)->
					cache.del gid if not err
					cb undefined, game.analysis, find_disagree(game.analysis)

calc = exports.calc = (gid, cb)->
	get_game gid, (err, game)->
		return cb err if err
		return cb new Error "calc: need analysis" if not game.analysis
		regiments = rule.analyze game.moves
		_.each game.analysis, (x)->
			stone = x.domains[0].stone_blocks[0].block[0].n
			r = rule.find_regiment regiments, stone
			throw new Error "no regiment found for stone #{stone} in #{gid}" if not r
			r.judge = x.judge or x.guess
		nums = rule.calc regiments, game.moves
		cb undefined,
			black: nums.black.occupied - nums.black.repealed
			white: nums.white.occupied - nums.white.repealed
			nums: nums
		