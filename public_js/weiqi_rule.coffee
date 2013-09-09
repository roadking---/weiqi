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
