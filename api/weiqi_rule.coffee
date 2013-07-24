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
		throw new Error "already exists: not allowed in #{step.pos} #{step.player}"
	
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
	
	
	regiments = []
	_.each domains, (d)->
		r = _.find regiments, (r)-> d in r.domains
		if r
			r.domains = _.chain(r.domains).union(d.adjacent_domains.mine).uniq().value()
		else
			regiments.push domains: _.flatten [d, d.adjacent_domains.mine]
	_.each regiments, (r)->
		r.adjacent_regiments = _.chain(r.domains).map((x)->x.adjacent_domains.rival).flatten().uniq().map((d)-> _.find regiments, (r)-> d in r.domains).value()
	
	#now guessing true or false liberties
	
	regiments

exports?.analyze = analyze
window?.analyze = analyze
