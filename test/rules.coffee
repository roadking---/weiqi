_ = require 'underscore'
r = require '../api/weiqi_rule'
assert = require("assert")

circle_the_eye = (eye, player, stones)->
	_.chain(eye).map((x)-> [ [x[0]+1, x[1]], [x[0]-1, x[1]], [x[0], x[1]+1], [x[0], x[1]-1] ]).flatten(true).filter((x)-> 0 <= x[0] <= 18 and 0 <= x[1] <= 18).uniq((x)->19 * x[0] + x[1]) \
	.reject((x)-> _.find eye, (y)-> x[0] is y[0] and x[1] is y[1]).each (x)->
		try
			r.move_step stones, {pos:x, player:player}
		catch e

describe 'rules', ->
	describe 'move_step', ->
		it 'move 1 step', (done)->
			stones = []
			rlt = r.move_step stones, {pos:[0, 1], player:'black'}
			assert not rlt
			assert stones.length
			done()
		it 'take the white stone', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			assert.throws -> r.move_step stones, {pos:[0, 1], player:'black'}
			assert stones.length
			done()
		it 'take the white stone', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[0, 0], player:'white'}
			rlt = r.move_step stones, {pos:[1, 0], player:'black'}
			assert.equal stones[1].repealed, 2
			assert rlt
			assert.equal rlt.length, 1
			assert.equal rlt[0].block.length, 1
			assert.equal rlt[0].block[0].player, 'white'
			assert.equal rlt[0].opposite.length, 2
			assert not rlt[0].liberty.length
			done()
		it 'liberty rule', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[0, 0], player:'white'}
			assert r.move_step stones, {pos:[1, 0], player:'black'}
			assert.throws -> r.move_step stones, {pos:[0, 0], player:'white'}
			assert.equal stones.length, 3
			done()
	
	describe 'move_step', ->
		stones = []
		before (done)-> 
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[1, 1], player:'white'}
			r.move_step stones, {pos:[1, 0], player:'black'}
			r.move_step stones, {pos:[2, 0], player:'white'}
			r.move_step stones, {pos:[10, 0], player:'black'}
			done()
		it 'the ko rule', (done)->
			assert rlt = r.move_step stones, {pos:[0, 0], player:'white'}
			assert.equal rlt[0].block[0].player, 'black'
			assert.equal stones[2].repealed, 5
			assert.throws -> r.move_step stones, {pos:[1, 0], player:'black'}
			assert.equal stones.length, 6
			
			r.move_step stones, {pos:[10, 1], player:'black'}
			r.move_step stones, {pos:[10, 2], player:'white'}
			assert r.move_step stones, {pos:[1, 0], player:'black'}
			assert.equal stones[5].repealed, 8
			assert.throws -> r.move_step stones, {pos:[0, 0], player:'white'}
			
			r.move_step stones, {pos:[10, 3], player:'white'}
			r.move_step stones, {pos:[10, 4], player:'black'}
			assert r.move_step stones, {pos:[0, 0], player:'white'}
			assert.equal stones[8].repealed, 11
			done()

	describe 'retract', ->
		it 'simplest case', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			assert stones.length
			r.retract stones
			assert not stones.length
			done()
		it 'restore the taken stone', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[0, 0], player:'white'}
			assert r.move_step stones, {pos:[1, 0], player:'black'}
			r.retract stones
			assert.equal stones.length, 2
			assert not stones[1].repealed
			done()
	
	describe 'analyze', ->
		find_domain = (domains, pos)->
			_.find domains, (d)->
				_.chain(d.stone_blocks).pluck('block').flatten().pluck('pos').find((x)-> 
					x[0] is pos[0] and x[1] is pos[1]).value()
		
		it 'simplest case', (done)->
			stones = []
			r.move_step stones, {pos:[3, 3], player:'black'}
			r.move_step stones, {pos:[3, 15], player:'white'}
			regiments = r.analyze stones
			rlt = _.chain(regiments).pluck('domains').flatten().value()
			assert.equal rlt.length, 2
			done()
		it 'black player has his own liberities', (done)->
			stones = []
			r.move_step stones, {pos:[2, 0], player:'black'}
			r.move_step stones, {pos:[2, 1], player:'black'}
			r.move_step stones, {pos:[1, 2], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[3, 15], player:'white'}
			regiments = r.analyze stones
			rlt = _.chain(regiments).pluck('domains').flatten().value()
			assert.equal rlt.length, 2
			assert black_domain = _.findWhere rlt, player:'black'
			assert.equal _.chain(black_domain.stone_blocks).pluck('block').flatten().value().length, 4
			assert.equal _.chain(black_domain.liberty_blocks).pluck('liberties').flatten(true).value().length, 4
			done()
		it 'domains', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[1, 0], player:'black'}
			r.move_step stones, {pos:[1, 2], player:'black'}
			r.move_step stones, {pos:[2, 1], player:'black'}
			r.move_step stones, {pos:[3, 15], player:'white'}
			regiments = r.analyze stones
			rlt = _.chain(regiments).pluck('domains').flatten().value()
			assert.equal rlt.length, 2
			assert black_domain = _.findWhere rlt, player:'black'
			assert.equal _.chain(black_domain.stone_blocks).pluck('block').flatten().value().length, 4
			assert.equal _.chain(black_domain.liberty_blocks).pluck('liberties').flatten(true).value().length, 2
			assert.equal black_domain.liberty_blocks_peripheral.length, 1
			assert black_domain.liberty_blocks_peripheral[0].liberties.length > 100
			stone10 = _.find black_domain.stone_blocks, (x)-> x.block[0].pos[0] is 1 and x.block[0].pos[1] is 0
			assert.equal stone10.liberty_blocks.length, 3
			assert.equal stone10.liberty_blocks_owned.length, 2
			#_.each rlt, (x)-> console.log _.chain(x.stone_blocks).pluck('block').flatten().value()
			done()
		it 'adjacent_domains', (done)->
			stones = []
			r.move_step stones, {pos:[0, 0], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 3], player:'white'}
			r.move_step stones, {pos:[2, 3], player:'white'}
			r.move_step stones, {pos:[3, 2], player:'white'}
			r.move_step stones, {pos:[3, 1], player:'white'}
			r.move_step stones, {pos:[3, 0], player:'white'}
			r.move_step stones, {pos:[15, 15], player:'black'}
			regiments = r.analyze stones
			assert.equal regiments.length, 3
			rlt = _.chain(regiments).pluck('domains').flatten().value()
			assert.equal rlt.length, 5
			d = find_domain rlt, [0,2]
			assert.equal d.liberty_blocks_peripheral.length, 1
			assert.equal d.liberty_blocks_peripheral[0].liberties.length, 7
			assert.equal d.adjacent_domains.mine.length, 1
			assert.equal d.adjacent_domains.rival.length, 2
			
			#console.log d.liberty_blocks[0].stone_blocks
			#_.each rlt, (x)-> console.log _.chain(x.stone_blocks).pluck('block').flatten().value()
			done()
		it 'false liberty', (done)->
			stones = []
			r.move_step stones, {pos:[1, 1], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[2, 2], player:'black'}
			r.move_step stones, {pos:[1, 3], player:'black'}
			r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 4], player:'white'}
			r.move_step stones, {pos:[2, 3], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [1, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.liberty_blocks.length, 1
			assert eye = r.find_eye regiments, [1, 2]
			assert not eye.eye
			done()
		it 'true liberty', (done)->
			stones = []
			r.move_step stones, {pos:[1, 1], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[2, 2], player:'black'}
			r.move_step stones, {pos:[1, 3], player:'black'}
			#r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 4], player:'white'}
			r.move_step stones, {pos:[2, 3], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [1, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.liberty_blocks.length, 1
			assert eye = r.find_eye regiments, [1, 2]
			assert eye.eye
			done()
		it 'true liberty 2', (done)->
			stones = []
			r.move_step stones, {pos:[1, 1], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[2, 2], player:'black'}
			r.move_step stones, {pos:[1, 3], player:'black'}
			_.each [0..3], (i)->
				r.move_step stones, {pos:[i, 4], player:'white'}
				r.move_step stones, {pos:[4, i], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [1, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.liberty_blocks.length, 1
			assert eye = r.find_eye regiments, [1, 2]
			assert eye.eye
			done()
		it 'false liberty 2', (done)->
			stones = []
			r.move_step stones, {pos:[1, 1], player:'black'}
			r.move_step stones, {pos:[0, 2], player:'black'}
			r.move_step stones, {pos:[2, 2], player:'black'}
			r.move_step stones, {pos:[1, 3], player:'black'}
			r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 4], player:'white'}
			r.move_step stones, {pos:[2, 1], player:'white'}
			r.move_step stones, {pos:[3, 1], player:'white'}
			r.move_step stones, {pos:[3, 2], player:'white'}
			r.move_step stones, {pos:[3, 3], player:'white'}
			r.move_step stones, {pos:[3, 4], player:'white'}
			r.move_step stones, {pos:[2, 4], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [1, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.liberty_blocks.length, 1
			assert eye = r.find_eye regiments, [1, 2]
			assert not eye.eye?
			done()
		it 'regiments guess 1', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[1, 0], player:'black'}
			r.move_step stones, {pos:[2, 1], player:'black'}
			r.move_step stones, {pos:[1, 2], player:'black'}
			r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 3], player:'white'}
			r.move_step stones, {pos:[2, 3], player:'white'}
			r.move_step stones, {pos:[3, 2], player:'white'}
			r.move_step stones, {pos:[3, 1], player:'white'}
			r.move_step stones, {pos:[3, 0], player:'white'}
			r.move_step stones, {pos:[15, 3], player:'black'}
			regiments = r.analyze stones
			assert.equal regiments.length, 3
			assert regiment = r.find_regiment regiments, [0, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.guess, 'live'
			assert eye = r.find_eye regiments, [0, 0]
			assert eye.eye
			assert eye = r.find_eye regiments, [1, 1]
			assert eye.eye
			done()
		it 'regiments guess 2', (done)->
			stones = []
			r.move_step stones, {pos:[0, 1], player:'black'}
			r.move_step stones, {pos:[1, 0], player:'black'}
			r.move_step stones, {pos:[2, 1], player:'black'}
			r.move_step stones, {pos:[0, 3], player:'white'}
			r.move_step stones, {pos:[1, 3], player:'white'}
			r.move_step stones, {pos:[2, 3], player:'white'}
			r.move_step stones, {pos:[3, 2], player:'white'}
			r.move_step stones, {pos:[3, 1], player:'white'}
			r.move_step stones, {pos:[3, 0], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [3, 1]
			assert.equal regiment.player, 'white'
			assert.equal regiment.guess, 'live'
			assert regiment = r.find_regiment regiments, [0, 1]
			assert.equal regiment.player, 'black'
			assert.equal regiment.guess, 'dead'
			done()
		it 'regiments guess 3', (done)->
			stones = []
			circle_the_eye [[0,0], [1,0], [0,1],[1,1]], 'black', stones
			_.each [0..8], (x)->
				r.move_step stones, {pos:[9, x], player:'white'}
				r.move_step stones, {pos:[x, 9], player:'white'}
			r.move_step stones, {pos:[0, 0], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 3
			assert regiment = r.find_regiment regiments, [1, 2]
			assert.equal regiment.player, 'black'
			assert.equal regiment.guess, 'dead'
			assert regiment = r.find_regiment regiments, [0, 0]
			assert.equal regiment.player, 'white'
			assert.equal regiment.guess, 'live'
			done()
		it 'regiments guess 4', (done)->
			stones = []
			circle_the_eye [[0,0], [1,0], [0,1],[1,1],[0,2]], 'black', stones
			_.each [0..8], (x)->
				r.move_step stones, {pos:[9, x], player:'white'}
				r.move_step stones, {pos:[x, 9], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			assert regiment = r.find_regiment regiments, [1, 2]
			assert.equal regiment.player, 'black'
			assert.equal regiment.guess, 'live'
			done()
		it 'regiments guess 5', (done)->
			stones = []
			circle_the_eye [[0,0], [1,0], [0,1],[1,1],[0,2]], 'black', stones
			_.each [0..8], (x)->
				r.move_step stones, {pos:[9, x], player:'white'}
				r.move_step stones, {pos:[x, 9], player:'white'}
			r.move_step stones, {pos:[0, 0], player:'white'}
			r.move_step stones, {pos:[0, 2], player:'white'}
			regiments = r.analyze stones
			assert.equal regiments.length, 3
			assert regiment = r.find_regiment regiments, [1, 2]
			assert.equal regiment.player, 'black'
			assert.equal regiment.guess, 'live'
			assert regiment = r.find_regiment regiments, [0, 0]
			assert.equal regiment.player, 'white'
			assert.equal regiment.guess, 'dead'
			done()
		
	describe 'calc', ->
		it 'both live', (done)->
			stones = []
			circle_the_eye _.map([0..6], (x)-> [x, 0]), 'black', stones
			circle_the_eye _.map([0..6], (x)-> [18-x, 18]), 'white', stones
			regiments = r.analyze stones
			assert.equal regiments.length, 2
			rlt = r.calc regiments
			assert.equal rlt.black.occupied, 7
			assert.equal rlt.white.occupied, 7
			done()
		it 'dead', (done)->
			stones = []
			tmp = _.chain([0..6]).map((x)-> _.map [0..6], (y)-> [x, y]).flatten(true).value()
			circle_the_eye tmp, 'black', stones
			r.move_step stones, {pos:[0, 0], player:'black'}
			circle_the_eye _.map(tmp, (x)-> [18-x[0], 18-x[1]]), 'white', stones
			circle_the_eye _.map(tmp, (x)-> [0, 0]), 'white', stones
			regiments = r.analyze stones
			assert.equal regiments.length, 3
			rlt = r.calc regiments, stones
			assert.equal rlt.black.occupied, 49
			assert.equal rlt.white.occupied, 49
			assert.equal rlt.black.repealed, 1
			assert.equal rlt.white.repealed, 0
			done()
	
	
	describe 'match_shape', ->
		it '直四', (done)->
			positions = _.map [1..4], (i)-> [3, i]
			assert r.match_shape positions, '直四'
			assert not r.match_shape positions, '曲四'
			assert not r.match_shape positions, '方四'
			done()