$ ->
	console.log data
	init_header data
	$('nav #home').parent().addClass('active')
	
	if not data.myself
		$('a#prev_blogs_btn').remove()
	
	render_blog = (blog)->
		div = $(tpl('#blog_tpl') _.defaults(blog:blog, data)).appendTo $('#blogs ul')
		div.find('.del').click -> 
			$.get "/delete_post/#{blog.id}", (res)->
				if res.success
					div.animate {opacity:0, 'background-color':'#c70851'}, 300, 'ease', -> 
						div.animate {height:0, margin:0, padding:0, 'border-width':0}, 300, 'ease', -> div.remove()
			
		if blog.ss
			_.each blog.ss, (ss)->
				moves = data.refs[ss.gid].moves[0...ss.from]
				moves = _.chain(moves).reject((z)->_.find ss.moves, (y)-> z.n is y.n ).union(ss.moves).value()
				new BoardCanvas(
					div.find(".ss[ss='#{ss.name}']"), size:150
				).render(moves)

	if data.blogs
		$('<ul></ul>').appendTo $('#blogs')
		_.each data.blogs, (blog)-> render_blog blog
			
	if data.myself && data.games.attendings.length
		$(tpl('#attendings_tpl') data, {variable:'data'}).appendTo( $('#attendings') ).find('li').each (i, li)->
			if $(li).find('.thumb').length
				new BoardCanvas($(li).find('.thumb')).render data.refs[data.games.attendings[i]].moves
	
	if data.games.pendings.length
		$(tpl('#pendings_tpl') data, {variable:'data'}).appendTo( $('#pendings') )
	
	$('#prev_blogs_btn').click ->
		$.get "/blog?blog_id=#{data.myself}&tag=next", (res)->
			if res.success
				if res.blogs?.length
					blog_id_set = _.pluck data.blogs, 'id'
					res.blogs = _.reject res.blogs, (x)-> x.id in blog_id_set
					data.blogs = _.union data.blogs, res.blogs
						
				if res.blogs?.length
					_.each res.blogs, (blog)->
						data.refs = _.defaults data.refs, res.refs
						render_blog blog