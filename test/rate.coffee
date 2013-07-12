_ = require 'underscore'
assert = require("assert")
api = require '../api'
flow = require '../api/flow'

describe 'title', ->
	test_users = 'test1@test.com test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	gid = null
	beforeEach (done)-> 	
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			api.init_game {initiator: users[0], type: 'weiqi', players:users[0..1], seats:{black:users[0], white:users[1]}, social:true, start:'auto'}, (err, test_gid)->
				gid = test_gid
				api.move gid, {next:'white', move:{n:0, pos:[0, 0], player:'black'}}, (err)->
					api.move gid, {next:'black', move:{n:0, pos:[0, 1], player:'white'}}, (err)->
						done()
	afterEach (done)->
		api.discard_game gid, ->
			flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	
	describe 'game_rating', ->
		it 'noraml', (done)->
			api.surrender gid, users[0], (err, rlt)->
				assert not err
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
