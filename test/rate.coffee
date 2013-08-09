_ = require 'underscore'
assert = require("assert")
api = require '../api'
async = require 'async'

describe 'title', ->
	test_users = 'test6@test.com test7@test.com test8@test.com'.split ' '
	password = '12345678'
	users = null
	gid = null
	beforeEach (done)-> 	
		async.map test_users, ((x, cb)->api.register {email:x, password:password}, (err, id)-> cb undefined, id), (err, uids)->
			users = uids
			api.init_game {initiator: users[0], type: 'weiqi', players:users[0..1], seats:{black:users[0], white:users[1]}, social:true, start:'auto'}, (err, test_gid)->
				gid = test_gid
				api.move gid, {next:'white', move:{n:0, pos:[0, 0], player:'black'}}, (err)->
					api.move gid, {next:'black', move:{n:0, pos:[0, 1], player:'white'}}, (err)->
						done()
	afterEach (done)->
		api.discard_game gid, ->
			async.each test_users, ((x, cb)->api.discard_user x, cb), done
	
	describe 'game_rating', ->
		it 'noraml', (done)->
			api.surrender gid, users[0], (err, rlt)->
				assert not err, err
				assert.equal rlt.win, 'white'
				api.game_rating rlt, (err, players)->
					assert not err
					assert players.black.title
					assert players.black.rate
					assert.equal players.black.total_games, 1
					assert.equal players.black.losses, 1
					assert not players.black.wins
					assert not players.black.draws
					assert.equal players.white.total_games, 1
					assert not players.white.losses
					assert.equal players.white.wins, 1
					assert not players.white.draws
					done()
