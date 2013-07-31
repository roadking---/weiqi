_ = require 'underscore'
assert = require("assert")
api = require '../api'
flow = require '../api/flow'

describe 'user', ->
	describe 'register', ->
		data = 
			email: 'reg@test.com'
			password: '12345678'
		before (done)-> api.discard_user data.email, (err)-> done()
		after (done)-> api.discard_user data.email, (err)-> done()
			
		it 'normal', (done)->
			api.register data, (err, uid)->
				assert not err
				assert uid
				api.register data, (err, uid)->
					assert err
					done()
				
describe 'user', ->
	describe 'login', ->
		data = 
			email: 'login@test.com'
			password: '12345678'
		before (done)-> api.register data, (err, id)-> done()
		after (done)-> 
			api.discard_user data.email, done
			
		it 'normal', (done)->
			api.login data.email, data.password, (err, uid)->
				assert not err
				assert uid
				done()

describe 'game', ->
	describe 'init', ->
		it 'normal', (done)->
			api.init_game {initiator: 'test', type: 'weiqi'}, (err, gid)->
				assert not err
				assert gid
				api.discard_game gid, done

describe 'game', ->
	test_gid = null
	test_users = 'test1@test.com test2@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		users = {}
		funcs = _.map test_users, (x)-> (cb)->
			api.register {email:x, password:password}, (err, id)->
				users[x] = id
				cb()
		funcs.push (cb)->
			opts = 
				initiator: 'test'
				type: 'weiqi'
			api.init_game opts, (err, gid)->
				assert not err
				assert gid
				test_gid = gid
				cb()
		flow.group funcs, ->done()
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'attend', ->
		it 'should success when init status', (done)->
			api.get_game test_gid, (err, data)->
				assert not err
				assert.equal data.status, 'init'
				assert.equal data.players.length, 0
				
				api.player_attend test_gid, _.values(users)[0], (err, rlt)->
					assert not err
					assert not rlt
					
					api.get_game test_gid, (err, data)->
						assert not err
						assert.equal data.status, 'init'
						assert.equal data.players.length, 1
						assert _.values(users)[0] in data.players
						
						api.player_attend test_gid, _.values(users)[1], (err, rlt)->
							assert not err
							assert rlt
							
							api.get_game test_gid, (err, data)->
								assert not err
								assert.equal data.status, 'taking_seat'
								assert.equal data.players.length, 2
								assert _.chain(users).values().every((x)-> x in data.players).value()
								
								api.player_attend test_gid, 'some_uid', (err, rlt)->
									assert err
									done()

describe 'game', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		users = []
		funcs = _.map test_users, (x)-> (cb)->
			api.register {email:x, password:password}, (err, id)->
				users.push id
				cb()
		funcs.push (cb)->
			opts = 
				initiator: 'test'
				type: 'weiqi'
			api.init_game opts, (err, gid)->
				assert not err
				assert gid
				test_gid = gid
				cb()
		flow.group funcs, ->
			flow.group _.map(users, (x)-> (cb)->
				api.player_attend test_gid, x, cb
			), -> done()
			
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'taking_seat', ->
		it 'should success', (done)->
			api.get_game test_gid, (err, data)->
				assert.equal data.status, 'taking_seat'
				api.taking_seat test_gid, black:users[0], (err, seats, all_arrived)->
					assert not err
					assert.equal seats.black, users[0]
					assert not seats.white
					assert not all_arrived
					api.get_game test_gid, (err, data)->
						assert not err
						assert.equal data.status, 'taking_seat'
						assert.equal data.seats.black, users[0]
						api.taking_seat test_gid, white:users[0], (err, seats, all_arrived)->
							assert not err
							assert.equal seats.white, users[0]
							assert not seats.black
							assert not all_arrived
							api.taking_seat test_gid, black:users[1], (err, seats, all_arrived)->
								assert not err
								assert.equal seats.white, users[0]
								assert.equal seats.black, users[1]
								assert all_arrived
								api.get_game test_gid, (err, data)->
									assert.equal data.status, 'taking_seat'
									assert.equal data.seats.white, users[0]
									assert.equal data.seats.black, users[1]
									done()
				
		it 'should fail when a nonplayer is trying to take seat', (done)->
			api.taking_seat test_gid, black:'unknown_user', (err, seats, all_arrived)->
				assert err
				done()

describe 'game', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		users = []
		funcs = _.map test_users, (x)-> (cb)->
			api.register {email:x, password:password}, (err, id)->
				users.push id
				cb()
		funcs.push (cb)->
			opts = 
				initiator: 'test'
				type: 'weiqi'
			api.init_game opts, (err, gid)->
				assert not err
				assert gid
				test_gid = gid
				cb()
		flow.group funcs, -> done()
			
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			

	describe 'start_game', ->
		it 'should fail when status init', (done)->
			api.get_game test_gid, (err, data)->
				assert.equal data.status, 'init'
				api.start_game test_gid, (err)->
					assert err
					done()
		
		it 'should fail with vacant seat, and finally succeed with both seats taken.', (done)->
			flow.group _.map(users, (x)-> (cb)->
				api.player_attend test_gid, x, cb
			), ->
				api.start_game test_gid, (err)->
					assert err
					api.taking_seat test_gid, black:users[0], (err, seats, all_arrived)-> api.start_game test_gid, (err)->
						assert err
						api.taking_seat test_gid, white:users[1], (err, seats, all_arrived)-> api.start_game test_gid, (err)->
							assert not err
							api.get_game test_gid, (err, data)->
								assert.equal data.status, 'started'
								done()

describe 'game', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
			
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'init_game', ->
		it 'auto start', (done)->
			opts = initiator: users[0], type: 'weiqi', players:[users[0]]
			api.init_game opts, (err, gid)->
				assert not err
				test_gid = gid
				api.get_game test_gid, (err, game)->
					assert.equal game.status, 'init'
					assert users[0] in game.players
					done()
	describe 'taking_seat', ->
		it 'auto taking_seat', (done)->
			opts = initiator: users[0], type: 'weiqi', players:[users[0]], seats:{white:users[0]}
			api.init_game opts, (err, gid)->
				assert not err
				test_gid = gid
				api.get_game test_gid, (err, game)->
					assert.equal game.status, 'taking_seat'
					assert users[0] in game.players
					assert.equal game.seats.white, users[0]
					done()
	describe 'start_game', ->
		it 'auto start', (done)->
			opts = initiator: users[0], type: 'weiqi', start:'auto', players:users, seats:{black:users[1], white:users[0]}
			api.init_game opts, (err, gid)->
				assert not err
				test_gid = gid
				api.get_game test_gid, (err, game)->
					assert.equal game.status, 'started'
					done()
	describe 'move', ->
		it 'start with predifined moves', (done)->
			opts = initiator: users[0], type: 'weiqi', start:'auto', players:users, seats:{black:users[1], white:users[0]}, moves:[{player:'black', pos:[3, 3]}, {player:'black', pos:[15, 3]}]
			api.init_game opts, (err, gid)->
				assert not err
				test_gid = gid
				api.get_game test_gid, (err, game)->
					assert.equal game.status, 'started'
					assert.equal game.moves.length, 2
					done()

describe 'game', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		users = []
		funcs = _.map test_users, (x)-> (cb)->
			api.register {email:x, password:password}, (err, id)->
				users.push id
				cb()
		funcs.push (cb)->
			opts = 
				initiator: 'test'
				type: 'weiqi'
			api.init_game opts, (err, gid)->
				assert not err
				assert gid
				test_gid = gid
				cb()
		flow.group funcs, -> done()
			
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'quit_game', ->
		it 'should discard the game when she is the only player left', (done)->
			api.player_attend test_gid, users[0], (err)->
				assert not err
				api.get_game test_gid, (err, data)->
					assert not err
					assert.equal data.status, 'init'
					assert users[0] in data.players
					api.player_quit test_gid, users[0], (err)->
						assert not err
						api.get_game test_gid, (err, data)->
							assert err
							done()
		it 'should just quit it with init status', (done)->
			api.player_attend test_gid, users[0], (err)-> api.player_attend test_gid, users[1], (err)-> api.get_game test_gid, (err, data)->
				assert.equal data.players.length, 2
				api.player_quit test_gid, users[0], (err)->
					assert not err
					api.get_game test_gid, (err, data)->
						assert not err
						assert not (users[0] in data.players)
						assert users[1] in data.players
						done()
		it 'quit when taking seat', (done)->
			flow.group _.map(users, (x)->(cb)-> api.player_attend test_gid, x, cb), ->
				api.taking_seat test_gid, black:users[0], (err, seats, all_arrived)-> api.get_game test_gid, (err, data)->
					assert.equal data.seats.black, users[0]
					assert.equal data.status, 'taking_seat'
					api.player_quit test_gid, users[0], (err)->
						assert not err
						api.get_game test_gid, (err, data)->
							assert not err
							assert not data.seats.black
							assert not (users[0] in data.players)
							assert.equal data.status, 'init'
							done()
		it 'quit when started', (done)->
			flow.group _.map(users, (x)->(cb)-> api.player_attend test_gid, x, cb), ->
				api.taking_seat test_gid, {black:users[0], white:users[1]}, (err, seats, all_arrived)-> api.start_game test_gid, (err)-> api.get_game test_gid, (err, data)->
					assert.equal data.status, 'started'
					api.player_quit test_gid, users[0], (err)->
						assert not err
						api.get_game test_gid, (err, data)->
							assert.equal data.status, 'need_player'
							assert not (users[0] in data.players)
							
							api.player_attend test_gid, users[0], (err)->
								assert not err
								api.get_game test_gid, (err, data)->
									assert.equal data.status, 'started'
									assert users[0] in data.players
									done()

describe 'game', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		opts = 
			initiator: 'test'
			type: 'weiqi'
		api.init_game opts, (err, gid)->
			test_gid = gid
			flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
				users = _.chain(arguments).toArray().pluck(0).value()
				flow.group _.map(users, (x)->(cb)-> api.player_attend test_gid, x, cb), -> api.taking_seat test_gid, {black:users[0], white:users[1]}, -> done()
		
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	
	describe 'move', ->
		it 'normal', (done)->
			api.start_game test_gid, (err)-> 
				data =
					next: 'white'
					move:
						n: 0
						pos: [0, 1]
						player: 'black'
				api.move test_gid, data, (err, rlt)->
					assert not err
					assert rlt.move
					assert not rlt.block_taken.length
					api.get_game test_gid, (err, game)->
						assert not err
						assert.equal game.next, data.next
						assert game.moves.length
						data =
							next: 'black'
							move:
								n: 1
								pos: [0, 0]
								player: 'white'
						api.move test_gid, data, (err, rlt)->
							assert not err
							assert not rlt.block_taken.length
							data =
								next: 'white'
								move:
									n: 2
									pos: [1, 0]
									player: 'black'
							api.move test_gid, data, (err, rlt)->
								assert not err
								assert rlt.block_taken.length
								assert.equal rlt.block_taken[0][0].player, 'white'
								done()
	describe 'retract', ->
		it 'normal', (done)->
			api.start_game test_gid, (err)-> 
				assert not err
				data =
					next: 'white'
					move:
						n: 0
						pos: [0, 1]
						player: 'black'
				api.move test_gid, data, (err, rlt)->
					assert not err
					api.get_game test_gid, (err, game)->
						assert not err
						assert game.moves.length
						assert.equal game.next, 'white'
						api.retract users[0], test_gid, (err)->
							assert not err
							api.get_game test_gid, (err, game)->
								assert not err
								assert not game.moves.length
								assert.equal game.next, 'black'
								done()
			
		it 'failed with wrong guy', (done)->
			api.start_game test_gid, (err)-> 
				assert not err
				data =
					next: 'white'
					move:
						n: 0
						pos: [0, 1]
						player: 'black'
				api.move test_gid, data, (err, rlt)->
					assert not err
					data =
						next: 'black'
						move:
							n: 1
							pos: [0, 2]
							player: 'white'
					api.move test_gid, data, (err, rlt)->
						assert not err
						api.get_game test_gid, (err, game)->
							assert not err
							assert game.moves.length
							assert.equal game.next, 'black'
							api.retract users[0], test_gid, (err)->
								assert err
								done()
		it 'block being taken', (done)->
			api.start_game test_gid, (err)-> 
				assert not err
				moves = [
					{
						next: 'white'
						move:
							n: 0
							pos: [0, 0]
							player: 'black'
					}
					{
						next: 'black'
						move:
							n: 1
							pos: [1, 0]
							player: 'white'
					}
					{
						next: 'white'
						move:
							n: 2
							pos: [1, 1]
							player: 'black'
					}
					{
						next: 'black'
						move:
							n: 3
							pos: [2, 0]
							player: 'white'
					}
					{
						next: 'white'
						move:
							n: 4
							pos: [2, 1]
							player: 'black'
					}
					{
						next: 'black'
						move:
							n: 5
							pos: [6, 0]
							player: 'white'
					}
				]
				flow.serialize _.map(moves, (x)->(cb)->api.move test_gid, x, cb), ->
					assert not err
					api.get_game test_gid, (err, game)->
						assert not err
						assert.equal game.moves.length, 6
						data =
							next: 'white'
							move:
								n: 6
								pos: [3, 0]
								player: 'black'
						api.move test_gid, data, (err, rlt)->
							assert not err
							assert rlt.block_taken
							api.get_game test_gid, (err, game)->
								assert not err
								assert.equal game.moves.length, 7
								assert.equal _.where(game.moves, {repealed:6}).length, 2
								api.retract users[0], test_gid, (err)->
									assert not err
									api.get_game test_gid, (err, game)->
										assert not err
										assert.equal game.moves.length, 6
										assert.equal _.where(game.moves, {repealed:6}).length, 0
										done()
		
	describe 'surrender', ->
		it 'fail when it is not in started status', (done)->
			api.get_game test_gid, (err, data)->
				assert.equal data.status, 'taking_seat'
				api.surrender test_gid, users[0], (err, rlt)->
					assert err
					done()
		it 'normal', (done)->
			api.start_game test_gid, (err)-> api.get_game test_gid, (err, data)->
				assert.equal data.status, 'started'
				find_games = (cb)->
					m = api.client.multi()
					_.each users[0..1], (u)->
						m.zrange [u, 'weiqi'].join('|'), 0, -1
						m.zrange [u, 'history'].join('|'), 0, -1
					m.exec (err, replies)->
						cb replies
				find_games (games)->
					assert test_gid in games[0]
					assert not (test_gid in games[1])
					assert test_gid in games[2]
					assert not (test_gid in games[3])
					api.surrender test_gid, users[0], (err, rlt)->
						assert not err
						assert.equal rlt.win, 'white'
						assert.equal rlt.case, 'black surrenders'
						assert.equal rlt.players.black, users[0]
						api.get_game test_gid, (err, data)->
							assert data.result
							assert.equal data.status, 'ended'
							find_games (games)->
								assert not (test_gid in games[0])
								assert test_gid in games[1]
								assert not (test_gid in games[2])
								assert test_gid in games[3]
								done()
	describe 'end_game', ->
		it 'normal', (done)->
			api.start_game test_gid, (err)-> api.get_game test_gid, (err, data)->
				assert.equal data.status, 'started'
				counting = 
					unit: 'zi'
					black: 100.25
					white: 115.75
				api.end_game test_gid, counting, (err, rlt)->
					assert not err
					assert.equal rlt.win, 'white'
					assert rlt.case
					api.get_game test_gid, (err, data)->
						assert data.result
						assert.equal data.status, 'ended'
						done()

describe 'friend', ->
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	
	describe 'follow', ->
		it 'A follow B', (done)->
			api.follow users[0], users[1], (err, rlt)->
				assert not err
				assert.equal rlt, 'followed'
				api.get_related users[0], ['friends', 'following', 'followed'], (err, rlt)->
					assert not err
					assert.equal rlt.friends.length, 0
					assert.equal rlt.following.length, 0
					assert.equal rlt.followed.length, 1
					assert users[1] in rlt.followed
					done()
		it 'A and B friends', (done)->
			api.follow users[0], users[1], (err, rlt)-> api.follow users[1], users[0], (err, rlt)->
				assert not err
				assert.equal rlt, 'friends'
				api.get_related users[0], ['friends', 'following', 'followed'], (err, rlt)->
					assert not err
					assert.equal rlt.friends.length, 1
					assert.equal rlt.following.length, 1
					assert.equal rlt.followed.length, 0
					api.get_related users[1], ['friends', 'following', 'followed'], (err, rlt)->
						assert not err
						assert.equal rlt.friends.length, 1
						assert.equal rlt.following.length, 1
						assert.equal rlt.followed.length, 0
						done()

describe 'user', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			opts = initiator: users[0], type: 'weiqi'
			api.init_game opts, (err, gid)->
				test_gid = gid
				flow.group _.map(users, (x)->(cb)-> api.player_attend test_gid, x, cb), -> api.taking_seat test_gid, {black:users[0], white:users[1]}, -> done()
		
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe.skip 'get_user_updates', ->
		it 'normal', (done)->
			api.follow users[0], users[1], (err, rlt)-> api.get_user_updates users[0], 'friend', (err, data)->
				assert not err
				assert test_gid in data.current_games
				assert data.following.length
				assert.equal data.following[0].followed, users[1]
				done()

describe 'user', ->
	test_gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			opts = initiator: users[0], type: 'weiqi'
			api.init_game opts, (err, gid)->
				test_gid = gid
				api.player_attend test_gid, users[0], -> done()
		
	afterEach (done)->
		api.discard_game test_gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe.skip 'get_user_updates', ->
		it 'my_new_game', (done)->
			api.get_user_updates users[0], 'friend', (err, data)->
				assert not err
				assert.equal data.my_new_game, test_gid
				opts = initiator: users[0], type: 'weiqi'
				api.init_game opts, (err, gid)->
					assert err
					api.player_attend test_gid, users[1], (err)->
						assert not err
						api.get_user_updates users[0], 'friend', (err, data)->
							assert not data.my_new_game
							done()


describe 'rating', ->
	gid = null
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			opts = initiator: users[0], type: 'weiqi', players: users, seats:{black:users[0], white:users[1]}, start:'auto'
			api.init_game opts, (err, test_gid)->
				gid = test_gid
				done()
		
	afterEach (done)->
		api.discard_game gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	
	describe 'surrender', ->
		it 'normal', (done)->
			api.surrender gid, users[0], (err, rlt)->
				assert not err
				assert.equal rlt.win, 'white'
				api.game_rating rlt, (err, players)->
					assert players.black.rate < players.white.rate
					api.get_user users[0], (err, user)->
						assert.equal user.rate, players.black.rate
						done()

describe 'group', ->
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'create_group', ->
		it 'normal', (done)->
			api.create_group data = {managers:[users[0]], name:'test'}, (err, gid)->
				assert not err
				assert gid
				api.get_group gid, (err, group)->
					assert not err
					assert users[0] in group.members
					done()
	describe 'join_group', ->
		it 'normal', (done)->
			api.create_group {managers:[users[0]], name:'test'}, (err, gid)->
				api.join_group users[1], gid, (err)->
					api.get_group gid, (err, group)->
						assert users[1] in group.members
						api.quit_group users[1], gid, (err)->
							assert not err
							api.get_group gid, (err, group)->
								assert not (users[1] in group.members)
								done()

describe 'social', ->
	test_users = 'test1@test.com test2@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		api.now = -> Math.round new Date().getTime()/1000
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'follow', ->
		it 'A follow B and both have a new blog', (done)->
			api.follow users[0], users[1], (err, rlt)->
				assert not err
				assert.equal rlt, 'followed'
				api.get_page users[0], (err, blogs)->
					assert not err
					assert blogs.length
					assert.equal blogs[0].type, 'followed'
					assert.equal blogs[0].A, users[0]
					assert.equal blogs[0].B, users[1]
					api.get_blogs users[0], 'my_blogs', (err, blogs)->
						assert not err
						assert blogs.length
						api.get_page users[1], (err, blogs)->
							assert not err
							assert blogs.length
							assert.equal blogs[0].type, 'followed'
							api.get_blogs users[1], 'my_blogs', (err, blogs)->
								assert not err
								assert not blogs.length
								done()
		it 'A follows B then B follows A, both have a new blog', (done)->
			api.follow users[0], users[1], (err, rlt)-> api.follow users[1], users[0], (err, rlt)->
				assert not err
				assert.equal rlt, 'friends'
				api.get_page users[0], (err, blogs)->
					assert not err
					assert blogs.length
					assert.equal blogs[0].type, 'friends'
					assert.equal blogs[0].A, users[1]
					assert.equal blogs[0].B, users[0]
					api.get_page users[1], (err, blogs)->
						assert not err
						assert blogs.length
						assert.equal blogs[0].A, users[1]
						assert.equal blogs[0].B, users[0]
						done()
		it 'A follow B, AF gets a blog but BF not', (done)->
			api.follow users[2], users[0], (err, rlt)-> api.follow users[3], users[1], (err, rlt)-> api.follow users[0], users[1], (err, rlt)-> 
				assert not err
				assert.equal rlt, 'followed'
				api.get_page users[2], (err, blogs)->
					assert not err
					assert _.findWhere blogs, type:'followed', A:users[0], B:users[1]
					api.get_page users[3], (err, blogs)->
						assert not err
						assert not _.findWhere blogs, type:'followed', A:users[0], B:users[1]
						done()
	describe 'unfollow', ->
		it 'normal', (done)->
			api.send_post users[0], {content:'test'}, (err, pid)->
				assert not err
				api.follow users[1], users[0], (err)->
					assert not err
					api.get_page users[1], (err, blogs)->
						assert not err
						assert _.findWhere blogs, content:'test'
						api.unfollow users[1], users[0], (err)->
							assert not err
							api.get_page users[1], (err, blogs)->
								assert not err
								assert not _.findWhere blogs, content:'test'
								done()
			
	describe 'get_page', ->
		it 'get recent blogs without cache', (done)->
			api.follow users[0], users[1], (err, rlt)->
				assert not err
				api.send_post users[1], {content:'test'}, (err, pid)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache)->
						assert not err
						assert.equal blogs[0].content, 'test'
						assert blog_cache.length
						done()
			
		it 'get recent blogs with cache', (done)->
			time = api.now()
			api.now = -> time - 60*60*3
			api.send_post users[1], {content:'test1'}, (err, pid)->
				assert not err
				api.now = -> time - 60*60*2
				api.follow users[0], users[1], (err, rlt)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache, page)->
						assert not err
						assert.equal blogs.length, 2
						assert.equal blogs[1].content, 'test1'
						assert blog_cache.length
						assert.equal page, 1
						api.now = -> time - 60*60*1
						api.get_page users[0], 'recent', (err, blogs, blog_cache)->
							assert.equal blogs.length, 2
							assert blog_cache.length
							done()
		it 'get next page without page record, which is equal to get recent ones', (done)->
			time = api.now()
			api.now = -> time - 60*60*3
			api.send_post users[1], {content:'test1'}, (err, pid)->
				assert not err
				api.now = -> time - 60*60*2
				api.follow users[0], users[1], (err, rlt)->
					assert not err
					api.get_page users[0], 'next', (err, blogs, blog_cache, page)->
						assert not err
						assert blogs.length
						assert.equal page, 1
						done()
		it 'get next page but there is no more blogs', (done)->
			time = api.now()
			api.now = -> time - 60*60*3
			api.send_post users[1], {content:'test1'}, (err, pid)->
				assert not err
				api.now = -> time - 60*60*2
				api.follow users[0], users[1], (err, rlt)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache, page)->
						assert not err
						assert.equal page, 1
						api.get_page users[0], 'next', (err, blogs, blog_cache, page)->
							assert not err
							assert not blogs.length
							done()
		it 'get next page', (done)->
			time = api.now()
			api.now = -> time - 60*60*3
			flow.serialize _.map([1..15], (x)-> (cb)->
				api.now = -> time - 60*60*x
				api.send_post users[1], {content:x}, cb
			), ->
				api.now = -> time
				api.follow users[0], users[1], (err, rlt)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache1, page)->
						assert not err
						assert 1 in _.pluck blogs, 'content'
						assert not (15 in _.pluck blogs, 'content')
						assert.equal page, 1
						api.get_page users[0], 'next', (err, blogs, blog_cache2, page)->
							assert not err
							assert not (1 in _.pluck blogs, 'content')
							assert 15 in _.pluck blogs, 'content'
							assert.equal page, 2
							assert blog_cache1[0][0] > blog_cache2[0][0]
							assert blog_cache1[0][1] is blog_cache2[0][1]
							api.get_page users[0], 'next', (err, blogs, blog_cache2, page)->
								assert not err
								assert not blogs.length
								done()
		it 'get next page with more followed', (done)->
			time = api.now()
			api.now = -> time - 60*60*3
			flow.serialize _.map([1..15], (x)-> (cb)->
				api.now = -> time - 60*60*x
				api.send_post users[1], {content:"1_#{x}"}, -> api.send_post users[2], {content:"2_#{x}"}, cb
			), ->
				api.now = -> time
				api.follow users[0], users[1], (err, rlt)-> api.follow users[0], users[2], (err, rlt)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache1, page)->
						assert not err
						assert '1_1' in _.pluck blogs, 'content'
						api.get_page users[0], 'next', (err, blogs, blog_cache2, page)->
							assert not err
							assert not ('1_1' in _.pluck blogs, 'content')
							assert '2_8' in _.pluck blogs, 'content'
							assert blog_cache1[0][0] is blog_cache2[0][0]
							assert blog_cache1[0][1] is blog_cache2[0][1]
							api.get_page users[0], 'next', (err, blogs, blog_cache2, page)->
								assert not err
								assert '2_15' in _.pluck blogs, 'content'
								done()
	describe 'get_refs', ->
		it 'a simple post case', (done)->
			api.send_post users[0], {text:'test'}, (err, pid)->
				assert not err
				api.get_page users[0], (err, blogs)->
					assert not err
					api.get_refs {blogs:blogs}, (err, refs)->
						assert not err
						assert refs[users[0]]
						done()
		it 'forwarding', (done)->
			api.send_post users[0], {text:'test'}, (err, pid)->
				assert not err
				api.forward_post users[1], 'aaa', pid, (err, fid1)->
					assert not err
					api.forward_post users[2], 'bbb', fid1, (err, fid2)->
						assert not err
						api.get_page users[2], (err, blogs)->
							assert not err
							api.get_refs {blogs:blogs}, (err, refs)->
								assert not err
								_.each users[0..2], (x)-> assert refs[x]
								assert blogs.length
								done()
		it 'posts from a game', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true, players:users[0..1], seats:{black:users[0], white:users[1]}, start:'auto'}, (err, gid)->
				assert not err
				api.get_page gid, (err, blogs)->
					assert not err
					api.get_refs {blogs:blogs, games:[gid]}, (err, refs)->
						assert not err
						_.each users[0..1], (x)-> assert refs[x]
						done()
	
	describe 'users_in_comment', ->
		it 'normal', (done)->
			assert 'u33956' in api.users_in_comment 'bbb//@{u33956}: aaa'
			done()
			
describe 'social', ->
	test_users = 'test1@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'send_post & fetch_blogs', ->
		it 'normal', (done)->
			api.send_post users[0], {content:'test'}, (err, pid)->
				assert not err
				assert pid
				api.fetch_blogs users[0], api.now(), 5, (err, blogs)->
					assert not err
					assert pid in _.pluck(blogs, 0)
					done()

describe 'social', ->
	test_users = 'test1@test.com test2@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			api.follow users[2], users[0], (err, rlt)-> api.follow users[3], users[1], (err, rlt)-> api.follow users[0], users[1], (err, rlt)-> done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'init_game', ->
		it 'init a game and share with friends', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true}, (err, gid)->
				assert not err
				api.get_game gid, (err, game)->
					assert not err
					assert game.social
					api.get_blogs gid, 'my_blogs', (err, blogs)->
						assert not err
						assert blogs.length
						api.get_page users[0], (err, blogs)->
							assert not err
							assert _.findWhere blogs, type:'init_game'
							assert _.findWhere blogs, type:'forward'
							api.get_page users[2], (err, blogs)->
								assert not err
								assert _.findWhere blogs, type:'forward'
								done()
	describe 'player_attend', ->
		it 'share it when user attends a game initiated by another guy', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true}, (err, gid)->
				assert not err
				api.player_attend gid, users[1], (err)->
					assert not err
					api.get_blogs gid, 'my_blogs', (err, blogs)->
						assert not err
						assert _.findWhere blogs, type:'player_attend'
						api.get_blogs users[1], 'my_blogs', (err, blogs)->
							assert not err
							assert _.findWhere blogs, type:'forward'
							done()
	describe 'follow_game and unfollow_game', ->
		it 'normal', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true}, (err, gid)->
				assert not err
				api.get_page users[1], (err, blogs)->
					assert not err
					assert not _.findWhere blogs, type:'init_game'
					api.follow_game users[1], gid, (err)->
						assert not err
						api.get_page users[1], (err, blogs)->
							assert not err
							assert _.findWhere blogs, type:'init_game'
							api.unfollow_game users[1], gid, (err)->
								assert not err
								api.get_page users[1], (err, blogs)->
									assert not err
									assert not _.findWhere blogs, type:'init_game'
									done()
	
	describe 'send_post', ->
		it 'normal', (done)->
			post = text:'test'
			api.send_post users[0], post, (err, pid)->
				assert not err
				assert pid
				api.get_blogs users[0], (err, blogs)->
					assert not err
					p = _.findWhere blogs, text:'test'
					assert p
					assert p.ts
					assert.equal p.author, users[0]
					done()
	describe 'forward_post', ->
		it 'forward a common post', (done)->
			post = text:'test'
			api.send_post users[0], post, (err, pid)->
				assert not err
				api.forward_post users[1], 'comment', pid, (err, fid)->
					assert not err
					assert fid
					done()
		it 'forward a forward', (done)->
			post = text:'test'
			api.send_post users[0], post, (err, pid)->
				assert not err
				api.forward_post users[1], 'comment', pid, (err, fid1)->
					assert not err
					api.forward_post users[2], 'xx', fid1, (err, fid2)->
						assert not err
						api.get_blogs users[2], (err, blogs)->
							assert not err
							p = _.findWhere blogs, type:'forward'
							assert.equal p.original, pid
							assert.equal p.original_blog.id, pid
							assert p.comment.indexOf('xx') > -1
							assert p.comment.indexOf('comment') > -1
							assert p.comment.indexOf(users[1]) > -1
							done()
	describe 'get_blogs', ->
		it 'get forwarded blog', (done)->
			post = text:'test'
			api.send_post users[0], post, (err, pid)->
				assert not err
				api.forward_post users[1], 'comment', pid, (err, fid)->
					assert not err
					api.get_blogs users[1], (err, blogs)->
						assert not err
						fp = _.findWhere blogs, type:'forward'
						assert fp
						assert.equal fp.original, pid
						assert.equal fp.comment, 'comment'
						assert.equal fp.author, users[1]
						assert.equal fp.original_blog.text, post.text
						assert.equal fp.original_blog.author, users[0]
						done()

describe 'social', ->
	test_users = 'test1@test.com test2@test.com test3@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'get_page', ->
		it 'player quit', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true, players:users[0..1], seats:{black:users[0], white:users[1]}, start:'auto'}, (err, gid)->
				assert not err
				api.get_page users[0], (err, blogs)->
					assert not err
					assert _.where(blogs, {gid:gid}).length
					api.player_quit gid, users[0], (err)->
						assert not err
						api.get_page users[0], (err, blogs)->
							assert not err
							assert _.where(blogs, {type:'player_quit'}).length
							done()
		it 'discart game', (done)->
			api.init_game {initiator: users[0], type: 'weiqi', social:true, players:users[0..1], seats:{black:users[0], white:users[1]}, start:'auto'}, (err, gid)->
				assert not err
				api.get_page users[0], (err, blogs)->
					assert not err
					assert _.where(blogs, {gid:gid}).length
					api.player_quit gid, users[0], (err)->
						assert not err
						api.get_page users[0], (err, blogs)->
							assert not err
							assert _.findWhere blogs, type:'init_game'
							api.discard_game gid, (err)->
								assert not err
								api.get_page users[0], (err, blogs)->
									assert not err
									done()
		
describe 'comment', ->
	gid = null
	test_users = 'test1@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			api.init_game {initiator: users[0], type: 'weiqi', players:users[0..1], seats:{black:users[0], white:users[1]}, social:true, start:'auto'}, (err, test_gid)->
				gid = test_gid
				done()
		
	afterEach (done)->
		api.now = -> Math.round new Date().getTime()/1000
		api.discard_game gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'add_comment', ->
		it 'comment game as a player', (done)->
			comment = ts: api.now(), text: 'test', step: 54, author: users[0]
			api.add_comment gid, comment, (err, pid)->
				assert not err
				assert pid
				api.get_blogs gid, (err, blogs)->
					assert not err
					assert _.findWhere blogs, type:'game_comment'
					api.get_blogs users[0], (err, blogs)->
						assert not err
						assert _.findWhere blogs, type:'forward'
						api.get_comments gid, (err, info)->
							assert not err
							assert (comment.step + '') in info.comments
							assert (comment.step + '') in info.comments_players
							api.get_comments gid, 'comments', 5, (err, info)->
								assert not err
								assert info[comment.step].length
								assert.equal info[comment.step][0].gid, gid
								done()
				
		it 'comment game as a nonplayer', (done)->
			comment = ts: api.now(), text: 'xx', step: '54', author: users[2]
			api.add_comment gid, comment, (err)->
				assert not err
				api.get_comments gid, (err, info)->
					assert (comment.step + '') in info.comments
					assert not ((comment.step + '') in info.comments_players)
					done()
		it 'fetch more comments', (done)->
			time = api.now()
			flow.serialize _.map([1..20], (x)-> (cb)->
				api.now = -> time - 3600 * x
				comment = ts: api.now(), text: x, step: '54', author: users[2]
				api.add_comment gid, comment, cb
			), ->
				api.get_comments gid, 'comments', 6, (err, info)->
					assert not err
					assert.equal info[54].length, 6
					api.get_comments gid, 'comments', 54, 6, 5, (err, info)->
						assert not err
						assert.equal info[54].length, 5
						assert.equal info[54][0].text, '6'
						done()
		it 'get snapshots with refs', (done)->
			api.move gid, {next:'white', move:{n:0, pos:[0,0], player:'black'}}, (err, rlt)->
				assert not err
				comment = 
					ts: api.now()
					text: 'xx'
					step: '0'
					author: users[2]
					snapshots: [
						{
							moves: [
								{
									pos: [0,1]
									player: 'white'
									n:1
								}
								]
							from: 0
							next: 'black'
						}
						]
					
				api.add_comment gid, comment, (err)->
					assert not err
					api.get_comments gid, 'comments', 5, (err, comments)->
						assert not err
						comments = _.chain(comments).values().flatten().value()
						assert.equal comments[0].type, 'game_comment'
						assert comments[0].gid
						api.get_refs {blogs:comments}, (err, refs)->
							assert not err
							assert refs[gid].moves.length
							done()


describe 'social', ->
	test_users = 'test1@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'delete_post', ->
		it 'simplest case', (done)->
			api.send_post users[0], {content:'test'}, (err, pid)->
				assert not err
				api.get_page users[0], 'recent', (err, blogs, blog_cache)->
					assert not err
					assert.equal blogs[0].content, 'test'
					assert blog_cache.length
					api.delete_post pid, (err)->
						assert not err
						api.get_page users[0], 'recent', (err, blogs, blog_cache)->
							assert not err
							assert not blogs.length
							done()
		it 'followed case', (done)->
			api.follow users[0], users[1], (err, rlt)->
				assert not err
				api.send_post users[1], {content:'test'}, (err, pid)->
					assert not err
					api.get_page users[0], 'recent', (err, blogs, blog_cache)->
						assert not err
						assert _.findWhere(blogs, {content:'test'})
						assert blog_cache.length
						api.delete_post pid, (err)->
							assert not err
							api.get_page users[0], 'recent', (err, blogs, blog_cache)->
								assert not err
								assert not _.findWhere(blogs, {content:'test'})
								done()

describe 'game', ->
	gid = null
	test_users = 'test1@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			api.init_game {initiator: users[0], type: 'weiqi', players:users[0..1], seats:{black:users[0], white:users[1]}, social:true, start:'auto'}, (err, test_gid)->
				gid = test_gid
				done()
		
	afterEach (done)->
		api.now = -> Math.round new Date().getTime()/1000
		api.discard_game gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
			
	describe 'retract', ->
		it 'move and retract repeatedly', (done)->
			api.move gid, {next:'white', move:{player:'black', pos:[0,0]}}, (err, data)->
				assert not err
				api.retract users[0], gid, (err)->
					assert not err
					api.move gid, {next:'white', move:{player:'black', pos:[0,0]}}, (err, data)->
						assert not err
						done()
	
	describe 'call_finishing', ->
		it 'ask', (done)->
			api.call_finishing gid, users[0], 'ask', (err)->
				assert not err
				api.get_game gid, (err, game)->
					assert not err
					assert.equal game.calling_finishing.uid, users[0]
					assert.equal game.calling_finishing.msg, 'ask'
					done()
		it 'cancel', (done)->
			api.call_finishing gid, users[0], 'cancel', (err)->
				assert not err
				api.get_game gid, (err, game)->
					assert not err
					assert not game.calling_finishing
					done()
		it 'accept while no asking', (done)->
			api.call_finishing gid, users[0], 'accept', (err)->
				assert err
				done()
		it 'accept while the same user', (done)->
			api.call_finishing gid, users[0], 'ask', (err)->
				assert not err
				api.call_finishing gid, users[0], 'accept', (err)->
					assert err
					done()
		it 'accept', (done)->
			api.call_finishing gid, users[0], 'ask', (err)->
				assert not err
				api.call_finishing gid, users[1], 'accept', (err)->
					assert not err
					api.get_game gid, (err, game)->
						assert not err
						assert.equal game.calling_finishing.uid, users[1]
						assert.equal game.calling_finishing.msg, 'accept'
						done()
		it 'reject', (done)->
			api.call_finishing gid, users[0], 'ask', (err)->
				assert not err
				api.call_finishing gid, users[1], 'reject', (err)->
					assert not err
					api.get_game gid, (err, game)->
						assert not err
						assert.equal game.calling_finishing.uid, users[1]
						assert.equal game.calling_finishing.msg, 'reject'
						done()
				
		