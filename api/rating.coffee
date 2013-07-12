_ = require 'underscore'
YAML = require('yamljs')
fs = require 'fs'
#http://movie.douban.com/review/4492302/?post=ok#last
#ELO rating System
#http://gobase.org
#http://www.usgo.org/ratings
#http://en.wikipedia.org/wiki/Elo_rating_system

###
user =
	friends:
		following: []
		followed: []
		inter_related: []
	game:
		playing: []
		closed: []
		live: []
		history:
	appraisal:
		style:
		title:
		status_quo:
		honor:
	trade:
		money:
		recharge:
		bet:
		shopping:
###

exports.config = config = YAML.parse fs.readFileSync("#{__dirname}/social_config.yml").toString()


k = (result_num, expected, user, game_result)-> 
	multiplier = if game_result.classfied then config.game_rate_classified[game_result.classfied] ? 1 else 1
	diff = _.find(config.levels, (x)-> x.min <= user.rate <= x.max).rate_diff
	Math.round multiplier * diff * (result_num - expected)

elo_rating = exports.elo_rating = (users, game_result)->
	result_num = if game_result.win is 'black'
		[1, 0]
	else if game_result.win is 'white'
		[0, 1]
	else
		[.5, .5]
	
	Q  = _.map users, (x)-> Math.pow 10, x.rate/400
	E = _.map Q, (x)-> x / (Q[0] + Q[1])
	_.chain(users).zip(result_num, E).map((x)->
		x[0].rate = x[0].rate + k(x[1], x[2], x[0], game_result)
	).value()

test = ->
	users = _.map [0..10], (x)->
		rate: 1500
		uid: x
		level: _.random 0, 14
		
	play = (users)->
		num = _.map users, (x)-> _.random x.level-3, x.level+3
		game_result =
			v: .1
			players:
				black: users[0]
				white: users[0]
		if num[0] > num[1]
			game_result.win = 'black'
		else if num[0] < num[1]
			game_result.win = 'white'
		else
			game_result.draw = true
		
		rates = elo_rating users, game_result
	
	_.each [0..1000], (x)->
		play _.shuffle(users)[0..1]
	
	_.chain(users).sortBy((x)->-x.rate).each (x)->
		console.log [x.level, x.rate].join "\t"

