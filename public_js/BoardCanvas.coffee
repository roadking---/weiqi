class window.BoardCanvas
	constructor: (canvas, @opts)->
		_.defaults this, @opts if @opts
		@LINE_COLOR ?= '#aaa'
		@NINE_POINTS_COLOR ?= '#53595e'
		@BACKGROUND ?= 'rgba(0,0,0,0)'
		@LINES ?= 19
		@size ?= 200
		@STONE_RADIUS ?= @size * .7 / 38 
		@NINE_POINTS_RADIUS ?= @STONE_RADIUS / 2.5
		@MARGIN ?= Math.round @STONE_RADIUS * 1.4
		@black = '#283734'
		@black_border = @black
		@white = '#fdfcf9'
		@white_border = @black_border
		
		if canvas[0].tagName isnt 'CANVAS'
			canvas = $('<canvas></canvas>').appendTo(canvas).attr(width: @size, height: @size)
		
		@ctx = canvas[0].getContext("2d")
		@interval = (@size - 2 * @MARGIN) / (@LINES - 1)
	circle: (x, y, radius, fill_color, stroke_color='black')=>
		x += .5
		y += .5
		@ctx.fillStyle = fill_color ? @black
		@ctx.strokeStyle = fill_color if not stroke_color
		@ctx.lineWidth = 1
		
		@ctx.beginPath()
		@ctx.arc x, y, radius, 0, Math.PI*2, false
		@ctx.closePath()
		@ctx.fill() if fill_color
		@ctx.stroke() if stroke_color
	locate: (n)-> Math.round @MARGIN + @interval * n
	position: (pos)->
		[x, y] = _.map pos, (num)=>
			num = (num - @MARGIN) / @interval
		[xx, yy] = _.map [x, y], (num)=>
			num = 0 if num < 0
			num = @LINES-1 if num > @LINES-1
			if 2* num >= Math.ceil(num) + Math.floor(num) then Math.ceil num else Math.floor num
		if Math.pow(x - xx, 2) + Math.pow(y - yy, 2) < Math.pow(.4, 2)
			[xx, yy]
	render: (stones)->
		@ctx.lineCap = 'round'
		@ctx.lineJoin = 'round'
		@ctx.lineWidth = .5
		@ctx.clearRect 0, 0, @size, @size
		@ctx.fillStyle = @BACKGROUND
		@ctx.fillRect 0, 0, @size, @size
		
		@ctx.fillStyle = @ctx.strokeStyle = @LINE_COLOR
		#@ctx.rect @MARGIN, @MARGIN, @size - 2 * @MARGIN, @size - 2 * @MARGIN
		_.each [0..@LINES-1], (n)=>
			@ctx.moveTo @locate(n)+.5, @locate(0)
			@ctx.lineTo @locate(n)+.5, @locate(@LINES-1)
			@ctx.stroke()
			@ctx.moveTo @locate(0), @locate(n)+.5
			@ctx.lineTo @locate(@LINES-1), @locate(n)+.5
			@ctx.stroke()
		_.each [
			[3, 3]
			[3, 9]
			[3, 15]
			[9, 9]
			[9, 3]
			[9, 15]
			[15, 3]
			[15, 9]
			[15, 15]
		], (x)=> @circle @locate(x[0]), @locate(x[1]), @NINE_POINTS_RADIUS, @NINE_POINTS_COLOR
		
		if stones
			@draw_stones stones
		else if @stones
			@draw_stones @stones
	draw_stones: (stones)->
		_.each stones, (s)=>
			if not s.repealed
				@circle @locate(s.pos[0]), @locate(s.pos[1]), @STONE_RADIUS, (if s.player is 'black' then @black else @white), (if s.player is 'black' then @black_border else @white_border)
		if last = stones[stones.length-1]
			@circle @locate(last.pos[0]), @locate(last.pos[1]), @STONE_RADIUS * .75, null, (if last.player is 'black' then @white else @black)