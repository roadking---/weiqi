_ = require 'underscore'

find = (stones, pos)-> _.filter(stones, (x)-> not x.repealed and x.pos[0] is pos[0] and x.pos[1] is pos[1])[0]

find_block = (stones, pos)->
	stone = find stones, pos
	return null if not stone
	
	block = [stone]
	liberty = []
	opposite = []
	newly_found = [stone]
	while newly_found.length
		adjacent = _.chain(newly_found).map((x)->
			[
				[x.pos[0] - 1, x.pos[1]]
				[x.pos[0] + 1, x.pos[1]]
				[x.pos[0], x.pos[1] - 1]
				[x.pos[0], x.pos[1] + 1]
			]
		).flatten(true).filter((x)->
			x[0] >= 0 and x[0] <= 18 and x[1] >= 0 and x[1] <= 18
		).uniq().reject((x)->
			_.chain([block, liberty, opposite]).flatten().some((y)-> y.pos[0] is x[0] and y.pos[1] is x[1]).value()
		).map((x)->
			find(stones, x) ? {pos:x, player:'none'}
		).value()
		if adjacent.length
			newly_found = _.filter adjacent, (x)-> x.player is stone.player
			liberty.push _.filter adjacent, (x)-> x.player is 'none'
			opposite.push _.filter adjacent, (x)-> x.player isnt 'none' and x.player isnt stone.player
			block = _.flatten [block, newly_found]
		else
			newly_found = []
	
	block: block
	liberty: _.chain(liberty).flatten().pluck('pos').groupBy((x)-> x.join ',').values().pluck(0).value()
	opposite: _.chain(opposite).flatten().groupBy((x)-> x.pos.join ',').values().pluck(0).value()
	
move = (stones, step, test=false)->
	if find stones, step.pos
		return new Error "already exists in #{step.pos}"
	
	step.n ?= stones.length
	stones.push step
	rlt = find_block stones, step.pos
	target_block = _.chain(rlt.opposite).map((x, i)->
		@target_block = [] if i is 0
		return null if _.chain(@target_block).pluck('block').flatten().some((y)-> x.pos[0] is y.pos[0] and x.pos[1] is y.pos[1]).value()
		block = find_block stones, x.pos
		@target_block.push block
		block
	).compact().reject((x)-> x.liberty.length).value()
	
	stones.pop() if test
	
	if target_block.length
		target_block
	else if rlt.liberty.length
		null
	else
		stones.pop() if not test
		throw new Error "not allowed in #{step.pos} #{step.player}"

repeal = (stones, block)->
	_.each block.block, (x)->
		x.repealed = stones.length - 1
	
move_step = (stones, step)->
	if _.any(stones, (x)->not x.repealed and x.pos[0] is step.pos[0] and x.pos[1] is step.pos[1])
		throw new Error "already exists: not allowed in #{JSON.stringify step}"
	
	try_move = ->
		blocks = move stones, step
		if blocks
			_.each blocks, (x)-> repeal stones, x
		blocks
	
	last = if stones?.length > 1 then stones[stones.length-1] else null
	blocks = try_move()
	
	#check the ko rule
	taken = _.pluck blocks, 'block'
	if last and taken.length is 1 and taken[0].length is 1
		taken = taken[0][0]
		if taken.player is last.player and _.every([0..1], (i)->last.pos[i] is taken.pos[i])
			if taken = _.where(stones, repealed: last.n)
				if taken.length is 1
					taken = taken[0]
					if taken.player is step.player and _.every([0..1], (i)->step.pos[i] is taken.pos[i])
						deprecated = stones.pop()
						_.each stones, (x)-> delete x.repealed if x.repealed is deprecated.n
						throw new Error "dajie: not allowed in #{step.pos} #{step.player}"
	
	blocks

exports?.move_step = move_step
window?.move_step = move_step

retract = (stones)->
	return stones if not stones.length
	last_step = stones.pop()
	_.chain(stones).where(repealed: last_step.n).each (x)-> delete x.repealed
	stones
exports?.retract = retract
window?.retract = retract


analyze = (stones)->
	stones_resident = _.reject stones, (x)-> x.repealed
	
	LINE_NUM = 19
	
	liberty_blocks = _.chain(stones_resident).pluck('pos').sortBy((x)-> LINE_NUM*x[0] + x[1]).groupBy((x)->x[0]).tap((x)->
		_.each [0...LINE_NUM], (y)->
			x[y] ?= []
	).pairs().map((x)->
		_.chain([0...LINE_NUM]).difference(_.pluck(x[1], 1)).map((y)->[Number(x[0]), y]).value()
	).map((line)->
		_.chain(line).groupBy((x, i, line)->
			while i and line[i][1] is line[i-1][1] + 1
				i--
			line[i][1]
		).values().value()
	).tap((all)->
		#console.log _.map all, (line, i)-> _.map line, (x)-> [ x[0][1], x[x.length-1][1] ]
	).map((line, i, all)->
		_.map line, (liberties)->
			liberties:liberties
			next_line_adjacent: \
			if i + 1 < all.length
				_.chain(all[i+1]).map((next_line_block, next_i)->
					if liberties[0][1] <= next_line_block[0][1] <= liberties[liberties.length-1][1] or liberties[0][1] <= next_line_block[next_line_block.length-1][1] <= liberties[liberties.length-1][1] \
					or next_line_block[0][1] <= liberties[0][1] <= next_line_block[next_line_block.length-1][1] or next_line_block[0][1] <= liberties[liberties.length-1][1] <= next_line_block[next_line_block.length-1][1]
						next_i
				).filter((x)-> x?).value()
	).map((line, i, all)->
		_.each line, (liberties, li, line)->
			if li and liberties.next_line_adjacent and _.intersection(liberties.next_line_adjacent, line[li-1].next_line_adjacent).length
				line[li-1].liberties = _.union line[li-1].liberties, liberties.liberties
				line[li-1].next_line_adjacent = _.chain(line[li-1].next_line_adjacent).union(liberties.next_line_adjacent).uniq().value()
				if i
					_.each all[0..i], (tmp_line)->
						_.each [0...tmp_line.length], (tmp_li)->
							if tmp_line[tmp_li] is line[li]
								tmp_line[tmp_li] = line[li-1]
				line[li] = line[li-1]
		
		_.chain(line).uniq().each (liberties, bi)->
			if liberties.next_line_adjacent?.length
				next_line_adjacent = liberties.next_line_adjacent
				liberties.liberties = _.chain(next_line_adjacent).map((next_i)->all[i+1][next_i].liberties).flatten(true).union(liberties.liberties).value()
				liberties.next_line_adjacent = _.chain(next_line_adjacent).map((next_i)->all[i+1][next_i].next_line_adjacent).flatten().uniq().filter((x)->x?).value()
				_.each next_line_adjacent, (next_i)->all[i+1][next_i] = liberties
		line
	).flatten(true).uniq().map((x)-> _.pick x, 'liberties').value()
	#console.log _.map liberty_blocks, (x)-> if x.liberties.length < 10 then x.liberties else x.liberties.length
	
	
	stone_blocks = []
	while stones_resident.length
		item = find_block stones, stones_resident[0].pos
		stone_blocks.push item
		block_stones = _.pluck item.block, 'n'
		stones_resident = _.reject stones_resident, (x)-> x.n in block_stones
	
	_.each stone_blocks, (x)->
		x.liberty_blocks = _.chain(x.liberty).map((y)->
			_.find liberty_blocks, (z)->
				_.some z.liberties, (tmp)-> 
					tmp[0] is y[0] and tmp[1] is y[1]
		).uniq().value()
		_.each x.liberty_blocks, (y)->
			y.stone_blocks ?= []
			y.stone_blocks.push x
	
	_.each liberty_blocks, (x)->
		x.stone_blocks = _.groupBy x.stone_blocks, (y)->
			y.block[0].player
	#console.log _.chain(liberty_blocks).map((x)-> liberties: x.liberties.length, stone_blocks:_.chain(x.stone_blocks).pairs().map((x)->[x[0], x[1].length]).object().value() ).value()
	
	
	domains = []
	_.chain(liberty_blocks).filter((x)->
		_.keys(x.stone_blocks).length is 1
	).each (x)->
		found = _.find domains, (y)->
			x in y.liberty_blocks or _.chain(x.stone_blocks).values().flatten(true).intersection(y.stone_blocks).value().length
		if found
			found.liberty_blocks.push x
			found.stone_blocks = _.union found.stone_blocks, _.values(x.stone_blocks)[0]
		else
			domains.push liberty_blocks:[x], stone_blocks:_.values(x.stone_blocks)[0]
	
	domains = _.chain(stone_blocks).difference(_.chain(domains).pluck('stone_blocks').flatten(true).value()).map((x)-> stone_blocks:[x]).union(domains).map((x)->
		x.player = x.stone_blocks[0].block[0].player
		x
	).value()
	
	_.each domains, (d)->
		if d.liberty_blocks
			_.each d.stone_blocks, (sb)->
				sb.liberty_blocks_owned = _.intersection(sb.liberty_blocks, d.liberty_blocks)
		d.liberty_blocks_peripheral = _.chain(d.stone_blocks).pluck('liberty_blocks').flatten().uniq().difference(d.liberty_blocks).value()
	
	is_stone_in_domain = (stone, domain)-> stone in _.chain(domain.stone_blocks).pluck('block').flatten().value()
	_.each domains, (d)->
		d.adjacent_domains = []
		_.chain(d.stone_blocks).pluck('opposite').flatten(true).uniq().each (stone)->
			if not _.some(d.adjacent_domains, (tmp_d)->is_stone_in_domain(stone, tmp_d))
				d.adjacent_domains.push domain_found = _.find domains, (tmp_d)-> tmp_d isnt d and is_stone_in_domain(stone, tmp_d)
		
		_.chain(d.liberty_blocks_peripheral).pluck('stone_blocks').map((x)->_.values x).flatten().uniq().each (sb)->
			if not (sb in d.stone_blocks) and not _.find(d.adjacent_domains, (tmp_d)-> sb in tmp_d.stone_blocks)
				d.adjacent_domains.push _.find domains, (tmp_d)-> tmp_d isnt d and not (tmp_d in d.adjacent_domains) and sb in tmp_d.stone_blocks
		
		d.adjacent_domains = 
			mine: _.where d.adjacent_domains, player:d.player
			rival: _.reject d.adjacent_domains, (x)-> x.player is d.player
	
	regiments = segment domains, (d)-> d.adjacent_domains.mine
	regiments = _.map regiments, (r)-> domains: r
	_.each regiments, (r)->
		r.player = r.domains[0].player
		r.adjacent_regiments = _.chain(r.domains).map((x)->x.adjacent_domains.rival).flatten().uniq().map((d)-> _.find regiments, (r)-> d in r.domains).value()
		r.liberty_blocks = _.chain(r.domains).pluck('liberty_blocks').flatten().compact().uniq().value()
		
	#eyes
	_.each regiments, (r)->
		_.each r.liberty_blocks, (lb)->
			if lb.liberties.length > 1
				lb.eye = true
			else if _.some(lb.stone_blocks[r.player], (sb)->sb.liberty_blocks.length <= 1)
				lb.eye = false
			else if 1 is _.chain(lb.stone_blocks[r.player]).map((sb)->
				proximity = [sb]
				while (peripherals = _.chain(proximity).pluck('liberty_blocks').flatten().without(lb).map((y)->y.stone_blocks[r.player]).flatten().uniq().difference(proximity).value()).length
					proximity = _.union proximity, peripherals
				_.chain(proximity).pluck('block').flatten().min((y)->y.n).value()
			).uniq().value().length
				lb.eye = true
			else
				1 # it depends if it connects to some true eyes. no need to care about this.
				
	
	#now guessing true or false liberties
	_.each regiments, (r)->
		if _.where(r.liberty_blocks, eye:true).length >= 2 or _.some(r.liberty_blocks, (lb)->lb.liberties.length >= 5 or match_shape(lb.liberties, '直四') or match_shape(lb.liberties, '曲四') )
			r.guess = 'live'
	#console.log regiments
	_.chain(regiments).reject((r)->r.guess?).each (r)->
		if _.every(r.adjacent_regiments, (ar)-> ar.guess is 'live')
			r.guess = 'dead'
	
	
	_.each (segment _.reject(regiments, (r)-> r.guess?), (r)-> _.reject r.adjacent_regiments, (ra)->ra.guess? ), (x)->
		x =_.chain(x).map((r)->
			r.liberty_count = _.chain(r.domains).pluck('stone_blocks').flatten().pluck('liberty').flatten(true) \
			.uniq((x)->19 * x[0] + x[1]).value().length
			r
		).sortBy((r)-> 
			r.liberty_count * 100 + r.liberty_blocks.length).value()
		if x.length is 2
			if x[0].liberty_count is x[1].liberty_count
				if x[0].liberty_blocks.length is x[1].liberty_blocks.length
					x[0].guess = x[1].guess = 'live' #共活
				else
					x[0].guess = 'dead'
					x[1].guess = 'live'
		_.chain(x).reject((r)->r.guess?).each (r)->
			#adj = _.reject r.adjacent_regiments, (ar)-> ar.guess?
			if _.some(r.adjacent_regiments, (ar)-> _.result(ar, 'guess') is 'dead')
				r.guess = 'live'
			else 
				target = _.chain(r.adjacent_regiments).reject((ar)->ar.guess?).filter((ar)->ar.liberty_count < r.liberty_count).value()
				if target.length is 2
					r.guess = 'live'
				if target.length is 1
					if _.filter(r.liberty_blocks.length, (lb)->lb.eye).length > 0
						r.guess = 'live'
					else if _.chain(target[0].domains).pluck('stone_blocks').flatten().pluck('block').flatten().value() >= 5
						r.guess = 'live'
					else
						target_stone_blocks = _.chain(target[0].domains).pluck('stone_blocks').flatten().uniq().value()
						supposed_empty = _.chain(r.domains).pluck('liberty_blocks_peripheral').flatten().uniq().filter((lb)-> 
							_.intersection(lb.stone_blocks[target[0].player], target_stone_blocks).length
						).pluck('liberties').flatten(true).union(
							_.chain(target_stone_blocks).pluck('block').flatten().pluck('pos').value()
						).value()
						if supposed_empty.length >= 5 or match_shape(supposed_empty, '直四') or match_shape(supposed_empty, '曲四')
							r.guess = 'live'
						else
							r.guess = 'dead'
				if r.guess is 'live'
					_.each target, (t)-> t.guess = 'dead' if not t.guess?
		_.chain(x).reject((r)->r.guess?).each (r)->
			if _.some(r.adjacent_regiments, (ar)-> _.result(ar, 'guess') is 'dead')
				r.guess = 'live'		
	regiments

exports?.analyze = analyze
window?.analyze = analyze


segment = (array, fn)->
		rlt = []
		_.each array, (d)->
			r = _.find rlt, (r)-> d in r.items
			if r
				r.items = _.chain(r.items).union(fn d).uniq().value()
			else
				rlt.push items: _.flatten [d, fn(d)]
		_.pluck rlt, 'items'
	

find_regiment = (regiments, stone)->
	_.find regiments, (r)->
		_.find r.domains, (d)->
			_.find d.stone_blocks, (sb)->
				_.find sb.block, (b)->
					if _.isArray stone
						b.pos[0] is stone[0] and b.pos[1] is stone[1]
					else
						b.n is stone
				
exports?.find_regiment = find_regiment

find_eye = (regiments, pos)->
	_.chain(regiments).pluck('liberty_blocks').flatten().find((lb)->
		_.find lb.liberties, (x)->
			x[0] is pos[0] and x[1] is pos[1]
	).value()
exports.find_eye = find_eye

match_shape = (positions, shape)->
	variance = (positions)->
		center = _.chain(positions).reduce((memo, x)->[memo[0] + x[0], memo[1] + x[1]]).map((x)->x/positions.length).value()
		_.chain(positions).map((x)-> Math.pow(x[0] - center[0], 2) + Math.pow(x[1] - center[1], 2)).reduce((memo, x)-> memo + x).value() / positions.length
	switch shape
		when '直四'
			positions.length is 4 and variance(positions) is variance([[0,0],[1,0],[2,0],[3,0]])
		when '曲四'
			positions.length is 4 and variance(positions) is variance([[0,0],[1,0],[2,0],[2,1]])
		when '方四'
			positions.length is 4 and variance(positions) is variance([[0,0],[1,0],[0,1],[1,1]])

exports.match_shape = match_shape

exports.calc = (regiments, stones)->
	repealed = _.chain(stones).filter((x)->x.repealed).countBy((x)->x.player).value()
	_.chain(regiments).map((x)->
		switch x.judge or x.guess
			when 'live'
				player: x.player
				occupied: _.chain(x.liberty_blocks).pluck('liberties').flatten(true).value()
			when 'dead'
				stones_taken = _.chain(x.domains).pluck('stone_blocks').flatten().pluck('block').flatten().pluck('pos').value()
				player: if x.player is 'black' then 'white' else 'black'
				occupied: _.union(
					stones_taken,
					_.chain(x.liberty_blocks).pluck('liberties').flatten(true).value(),
					_.chain(x.domains).pluck('liberty_blocks_peripheral').flatten().uniq().pluck('liberties').flatten(true).value()
				)
				stones_taken: stones_taken
				
	).groupBy((x)->x.player).pairs().map((x)->
		[ 
			x[0]
			{
				occupied: _.chain(x[1]).pluck('occupied').flatten(true).value().length
				repealed: repealed[x[0]] ? 0
			}
		]
	).object().value()
	