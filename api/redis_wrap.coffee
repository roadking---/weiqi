_ = require 'underscore'
flow = require './flow'
shared = require './shared'

multi = exports.multi = ->
	if not @m
		@m = shared.client.multi()
		@m._callbacks_ = []
	@m._concurrency_ ?= 0
	@m._concurrency_++
	@m._callbacks_.push {}
	if @m._concurrency_ is 1
		@m.exec = _.wrap @m.exec, (f, cb)=>
			@m._callbacks_[@m._callbacks_.length-1].cb = cb
			_.delay (=>
				@m._concurrency_--
				if not @m._concurrency_
					callbacks = @m._callbacks_
					f.apply @m, [(err, replies)=>
						_.each callbacks, (x)=>
							x.cb err, replies[0...x.replies]
							replies = replies[x.replies..]
					]
					@m = null
			), 0
		
		_.each 'hset hget get set del hdel zadd zremrangebyscore smembers zrange zrem sadd zrevrange sismember incr'.split(' '), (x)=>
			@m[x] = _.wrap @m[x], =>
				@m._callbacks_[@m._callbacks_.length-1].replies ?= 0
				@m._callbacks_[@m._callbacks_.length-1].replies++
				args = _.toArray arguments
				args[0].apply @m, _.rest(args)
	@m

###
f1 = -> 
	m = multi()
	m.hset 'f1', 'a', 'f1_a'
	m.hset 'f1', 'b', 'f1_b'
	test = 1
	m.exec (e)->
		console.log test
		m = multi()
		m.hget 'f1', 'a'
		m.hget 'f1', 'b'
		m.exec (e, r)->
			console.log r
			
f2 = -> 
	m = multi()
	m.hset 'f2', 'a', 'f2_a'
	m.hset 'f2', 'b', 'f2_b'
	m.exec (e)->
		m = multi()
		m.hget 'f2', 'a'
		m.hget 'f2', 'b'
		m.hget 'f2', 'b'
		m.exec (e, r)->
			console.log r

f1()
f2()
###
