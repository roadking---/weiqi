$ ->
	socket = io.connect "http://localhost/weiqi/weiqi|1"
	socket.emit 'auth', 'test cookie', (res)->
		console.log 'auth: ' + JSON.stringify res
		socket.emit 'move', pos:[3,3], player:'black', (res)->
			console.log 'move: ' + JSON.stringify res
			socket.emit 'discuss', 'xxx', (res)->
			socket.emit 'taking_seat', 'white', (res)-> console.log 'taking_seat: ' + JSON.stringify res
			socket.emit 'move', pos:[3,15], player:'white', (res)->
				console.log 'move: ' + JSON.stringify res
		
	socket.on 'attend', (res)-> console.log 'attend: ' + JSON.stringify res
	socket.on 'quit', (res)-> console.log 'quit: ' + JSON.stringify res
	socket.on 'start', (res)-> 
		console.log 'start: ' + JSON.stringify res
		socket.emit 'move', pos:[3,3], player:'black', (res)->
			console.log 'move: ' + JSON.stringify res
	socket.on 'move', (res)-> 
		console.log 'move: ' + JSON.stringify res
		@x ?= 18
		socket.emit 'move', pos:[@x--,3], player:'white', (res)-> console.log 'move: ' + JSON.stringify res
	#
	#socket.disconnect()