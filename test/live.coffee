_ = require 'underscore'
assert = require("assert")
api = require '../api'
flow = require '../api/flow'
live = require '../routes/live'

socket =
	on: ->
	emit: ->

describe 'io', ->
	beforeEach (done)-> done()
	afterEach (done)-> done()
	describe 'connect', ->
		it 'basic', (done)->
			done()