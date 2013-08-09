_ = require 'underscore'
assert = require("assert")
api = require '../api'
async = require 'async'

describe 'social', ->
	test_users = 'test3@test.com test4@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		async.map test_users, ((x, cb)->api.register {email:x, password:password}, (err, id)-> cb undefined, id), (err, uids)->
			users = uids
			done()
		
	afterEach (done)->
		async.each test_users, ((x, cb)->api.discard_user x, cb), done
			
	describe 'invite', ->
		it 'A invite B', (done)->
			api.invite users[0], users[1], (err, invite_id)->
				assert not err, err
				assert invite_id
				api.get_sent_invitation users[0], (err, invites)->
					assert not err
					assert invites.length
					assert.equal invites[0].receiver, users[1]
					api.get_received_invitation users[1], (err, invites)->
						assert not err
						assert invites.length
						assert.equal invites[0].receiver, users[1]
						done()
	
	describe 'get_sent_invitation', ->
		it 'remove the expired ones', (done)->
			ts = api.now()
			api.invite users[0], users[1], {expire:24*60*60}, (err, invite_id)->
				assert not err
				assert invite_id
				api.now = -> ts + 60
				api.get_sent_invitation users[0], (err, invites)->
					assert not err
					assert invites.length
					assert.equal invites[0].receiver, users[1]
					api.now = -> ts + 24*60*60*2
					api.cache.del "#{users[0]}_sent_invite"
					api.get_sent_invitation users[0], (err, invites)->
						assert not err
						assert not invites.length
						done()
						###
						api.client.get invite_id, (err, reply)->
							assert not reply
							done()
						###

	describe 'take_invitation', ->
		it 'without seats', (done)->
			api.invite users[0], users[1], (err, invite_id)->
				assert not err
				api.take_invitation invite_id, (err, gid)->
					assert not err
					assert gid
					api.get_game gid, (err, game)->
						assert not err
						assert.equal game.status, 'taking_seat'
						done()
		it 'with seats', (done)->
			opts =
				seats:
					black: users[0]
					white: users[1]
			api.invite users[0], users[1], opts, (err, invite_id)->
				assert not err
				api.get_sent_invitation users[0], (err, invites)->
					assert not err
					assert invites.length
					api.get_received_invitation users[1], (err, invites)->
						assert not err
						assert invites.length
						api.take_invitation invite_id, (err, gid)->
							assert not err
							assert gid
							api.get_game gid, (err, game)->
								assert not err
								assert.equal game.status, 'started'
								api.get_sent_invitation users[0], (err, invites)->
									assert not err
									assert not invites.length
									api.get_received_invitation users[1], (err, invites)->
										return done()
										assert not err
										console.log invites
										#assert not invites.length
										done()
	
	describe 'cancel_invite', ->
		it 'normal', (done)->
			api.invite users[0], users[1], (err, invite_id)->
				assert not err
				api.get_sent_invitation users[0], (err, invites)->
					assert not err
					assert invites.length
					api.get_received_invitation users[1], (err, invites)->
						assert not err
						assert invites.length
						api.cancel_invite users[0], users[1], (err)->
							assert not err
							api.get_sent_invitation users[0], (err, invites)->
								assert not err
								assert not invites.length
								api.get_received_invitation users[1], (err, invites)->
									assert not err
									assert not invites.length
									done()