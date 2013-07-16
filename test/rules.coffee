r = require '../api/weiqi_rule'
assert = require("assert")

describe 'rules', ->
	describe 'move_step', ->
		it 'move 1 step', (done)->
			items = []
			rlt = r.move_step items, {pos:[0, 1], player:'black'}
			assert not rlt
			assert items.length
			done()
		it 'take the white stone', (done)->
			items = []
			r.move_step items, {pos:[0, 1], player:'black'}
			assert.throws -> r.move_step items, {pos:[0, 1], player:'black'}
			assert items.length
			done()
		it 'take the white stone', (done)->
			items = []
			r.move_step items, {pos:[0, 1], player:'black'}
			r.move_step items, {pos:[0, 0], player:'white'}
			rlt = r.move_step items, {pos:[1, 0], player:'black'}
			assert.equal items[1].repealed, 2
			assert rlt
			assert.equal rlt.length, 1
			assert.equal rlt[0].block.length, 1
			assert.equal rlt[0].block[0].player, 'white'
			assert.equal rlt[0].opposite.length, 2
			assert not rlt[0].liberty.length
			done()
		it 'liberty rule', (done)->
			items = []
			r.move_step items, {pos:[0, 1], player:'black'}
			r.move_step items, {pos:[0, 0], player:'white'}
			assert r.move_step items, {pos:[1, 0], player:'black'}
			assert.throws -> r.move_step items, {pos:[0, 0], player:'white'}
			assert.equal items.length, 3
			done()
	
	describe 'move_step', ->
		items = []
		before (done)-> 
			r.move_step items, {pos:[0, 1], player:'black'}
			r.move_step items, {pos:[1, 1], player:'white'}
			r.move_step items, {pos:[1, 0], player:'black'}
			r.move_step items, {pos:[2, 0], player:'white'}
			r.move_step items, {pos:[10, 0], player:'black'}
			done()
		it 'the ko rule', (done)->
			assert rlt = r.move_step items, {pos:[0, 0], player:'white'}
			assert.equal rlt[0].block[0].player, 'black'
			assert.equal items[2].repealed, 5
			assert.throws -> r.move_step items, {pos:[1, 0], player:'black'}
			assert.equal items.length, 6
			
			r.move_step items, {pos:[10, 1], player:'black'}
			r.move_step items, {pos:[10, 2], player:'white'}
			assert r.move_step items, {pos:[1, 0], player:'black'}
			assert.equal items[5].repealed, 8
			assert.throws -> r.move_step items, {pos:[0, 0], player:'white'}
			
			r.move_step items, {pos:[10, 3], player:'white'}
			r.move_step items, {pos:[10, 4], player:'black'}
			assert r.move_step items, {pos:[0, 0], player:'white'}
			assert.equal items[8].repealed, 11
			done()

	describe 'retract', ->
		it 'simplest case', (done)->
			items = []
			r.move_step items, {pos:[0, 1], player:'black'}
			assert items.length
			r.retract items
			assert not items.length
			done()
		it 'restore the taken stone', (done)->
			items = []
			r.move_step items, {pos:[0, 1], player:'black'}
			r.move_step items, {pos:[0, 0], player:'white'}
			assert r.move_step items, {pos:[1, 0], player:'black'}
			r.retract items
			assert.equal items.length, 2
			assert not items[1].repealed
			done()