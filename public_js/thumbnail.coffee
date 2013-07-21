$ ->
	window.thumbnail = (moves, opts)->
		opts ?= {}
		size = opts.size ? 200
		
		_.defaults opts, NINE_POINTS_RADIUS:1.5, LINE_COLOR: '#aaa', click: false, NINE_POINTS_COLOR: '#53595e'
		opts.PAWN_RADIUS = Math.round size * .7 / 38 
		opts.margin = Math.round opts.PAWN_RADIUS * 1.4
		opts.size = size - 2 * opts.margin
		
		tn = $("<div class='thumb'><canvas class='draw'/></div>")
		tn.data 'game', moves:moves
		tn.append "<span class='title'>#{opts.title}</span>" if opts.title
		new CanvasBoard tn, opts
		tn