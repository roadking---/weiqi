$ ->
	$('a#follow').click ->
		uid = $('#profile').attr('_uid')
		if $(this).find('i').hasClass 'icon-white'
			$.get "/unfollow/#{uid}", (data)=>
				console.log data
				$(this).find('i').toggleClass 'icon-white'
		else
			$.get "/follow/#{uid}", (data)=>
				console.log data
				$(this).find('i').toggleClass 'icon-white'
	
	$('#user-games .thumb').each ->
		thumbnail(
			JSON.parse($(this).attr('game')).moves,
			{size: 300, LINE_COLOR: '#aaa', NINE_POINTS_COLOR: '#53595e'}
		).appendTo $(this).find('a')
	