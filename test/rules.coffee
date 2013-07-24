_ = require 'underscore'
r = require '../api/weiqi_rule'
assert = require("assert")

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
		it 'regiments', (done)->
			done()