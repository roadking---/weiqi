$ ->
	$('a#go2top').click ->
		h = document.body.scrollTop + document.documentElement.scrollTop
		t = setInterval (->
			scrollTo 0, h-=100
			if h <= 0
				clearInterval t
		), 5
	
	$(window).scroll (e)->
		h = document.body.scrollTop + document.documentElement.scrollTop
		if h > 10
			$('a#go2top').show()
		else
			$('a#go2top').hide()