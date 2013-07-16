_ = require 'underscore' if exports

find = (items, pos)-> _.filter(items, (x)-> not x.repealed and x.pos[0] is pos[0] and x.pos[1] is pos[1])[0]

find_block = (items, pos)->
	item = find items, pos
	return null if not item
	
	block = [item]
	liberty = []
	opposite = []
	newly_found = [item]
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
			find(items, x) ? {pos:x, player:'none'}
		).value()
		if adjacent.length
			newly_found = _.filter adjacent, (x)-> x.player is item.player
			liberty.push _.filter adjacent, (x)-> x.player is 'none'
			opposite.push _.filter adjacent, (x)-> x.player isnt 'none' and x.player isnt item.player
			block = _.flatten [block, newly_found]
		else
			newly_found = []
	
	block: block
	liberty: _.chain(liberty).flatten().pluck('pos').groupBy((x)-> x.join ',').values().pluck(0).value()
	opposite: _.chain(opposite).flatten().groupBy((x)-> x.pos.join ',').values().pluck(0).value()
	
move = (items, step, test=false)->
	if find items, step.pos
		return new Error "already exists in #{step.pos}"
	
	step.n ?= items.length
	items.push step
	rlt = find_block items, step.pos
	target_block = _.chain(rlt.opposite).map((x, i)->
		@target_block = [] if i is 0
		return null if _.chain(@target_block).pluck('block').flatten().some((y)-> x.pos[0] is y.pos[0] and x.pos[1] is y.pos[1]).value()
		block = find_block items, x.pos
		@target_block.push block
		block
	).compact().reject((x)-> x.liberty.length).value()
	
	items.pop() if test
	
	if target_block.length
		target_block
	else if rlt.liberty.length
		null
	else
		items.pop() if not test
		throw new Error "not allowed in #{step.pos} #{step.player}"

repeal = (items, block)->
	_.each block.block, (x)->
		x.repealed = items.length - 1
	
move_step = (items, step)->
	if _.any(items, (x)->not x.repealed and x.pos[0] is step.pos[0] and x.pos[1] is step.pos[1])
		throw new Error "already exists: not allowed in #{step.pos} #{step.player}"
	
	try_move = ->
		blocks = move items, step
		if blocks
			_.each blocks, (x)-> repeal items, x
		blocks
	
	last = if items?.length > 1 then items[items.length-1] else null
	blocks = try_move()
	
	#check the ko rule
	taken = _.pluck blocks, 'block'
	if last and taken.length is 1 and taken[0].length is 1
		taken = taken[0][0]
		if taken.player is last.player and _.every([0..1], (i)->last.pos[i] is taken.pos[i])
			if taken = _.where(items, repealed: last.n)
				if taken.length is 1
					taken = taken[0]
					if taken.player is step.player and _.every([0..1], (i)->step.pos[i] is taken.pos[i])
						deprecated = items.pop()
						_.each items, (x)-> delete x.repealed if x.repealed is deprecated.n
						throw new Error "dajie: not allowed in #{step.pos} #{step.player}"
	
	blocks

exports?.move_step = move_step
window?.move_step = move_step

retract = (items)->
	return items if not items.length
	last_step = items.pop()
	_.chain(items).where(repealed: last_step.n).each (x)-> delete x.repealed
	items
exports?.retract = retract
window?.retract = retract
