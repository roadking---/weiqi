class Weiqi extends ConnectedBoard
	on_connect: ->
		console.log 'connected'
		$('#live').show()
$ ->
	_.delay (->
		b = new Weiqi $('#live .board')
		$('#live #status').hide()
		$('#live #live_board').show()
	), 5000