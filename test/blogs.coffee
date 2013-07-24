_ = require 'underscore'
assert = require("assert")
jade = require("jade")
api = require '../api'
flow = require '../api/flow'
fs = require 'fs'

Guru = require __dirname + '/../node_modules/lingua/lib/guru'
config = 
	resources:
		defaultLocale: 'zh'
		path: __dirname + '/../public/i18n/'
		extension: '.json'
		placeholder: /\{(.*?)\}/
lingua = new Guru(config).ask('zh').content

title_fn = (t)-> lingua['title_' + t]
user_title_fn = _.wrap jade.compile(fs.readFileSync(__dirname + '/../views/view_fn/user_title_fn.jade').toString(), pretty:true, filename: __dirname + '/../views/widget/user_title.jade'), (f, opts)->
	opts.title = title_fn
	f opts
#return console.log user_title_fn title: title_fn, user:{id:1, username:'xx', title:'C'}
win_ratio_fn = (r)-> Math.round(r*1000)/10 + '%'
fn = jade.compile fs.readFileSync(__dirname + '/../views/blogs/blogs.jade').toString(), pretty:true, filename: __dirname + '/../views/widget/user_title.jade'
fn = _.wrap fn, (fn, locals)->
	locals.win_ratio_fn ?= win_ratio_fn
	locals.user_title_fn ?= user_title_fn
	locals.title ?= title_fn
	locals.lingua ?= lingua
	fn locals
	
dump = (blog_div)->
	console.log blog_div
	fs.writeFileSync "test_blog.html", \
	"""
	<!DOCTYPE html>
	<head>
		<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
		<link rel="stylesheet" href="http://localhost:5000/css/bootstrap.min.css">
		<link rel="stylesheet" href="http://localhost:5000/css/style.css">
		<script type="text/javascript" src="http://localhost:5000/js/jquery-1.9.1.min.js"></script>
		<script type="text/javascript" src="http://localhost:5000/js/moment.min.js"></script>
		<script type="text/javascript" src="http://localhost:5000/js/bootstrap.min.js"></script>
	</head>
	<body>
		<div id="blogs">
			<div class="row">
				<div class="span10 offset1">
					<div id="blogs_list">#{blog_div}</div>
				</div>
			</div>
		</div>
		<script>
			$(function() {
    return $('.ts').each(function() {
      return $(this).text(moment(Number($(this).attr('_ts')) * 1000).format('YYYY/MM/DD HH:mm'));
    });
  });
    </script>
	</body>
	"""

describe 'blogs view', ->
	test_gid = null
	test_users = 'Jane@test.com Eric@test.com'.split ' '
	password = '12345678'
	users = null
	beforeEach (done)-> 
		flow.group _.map(test_users, (x)-> (cb)-> api.register {email:x, password:password, nickname:x.split('@')[0]}, (err, id)-> cb id), -> 
			users = _.chain(arguments).toArray().pluck(0).value()
			done()
	afterEach (done)->
		flow.group _.map(test_users, (x)->(cb)->api.discard_user x, cb), -> done()
	describe 'init_game', ->
		it 'init_and_wait and a new user', (done)->
			opts = initiator: users[0], type: 'weiqi', players:[users[0]], social: true
			api.init_game opts, (err, gid)->
				assert not err
				api.get_page gid, (err, posts)->
					assert not err
					assert.equal posts[0].type, 'init_game'
					assert.equal posts[0].scenario, 'init_and_wait'
					api.get_refs {blogs:posts, users:_.pluck(users, 'id')}, (err, refs)->
						assert not err
						html = fn blogs:posts, refs:refs
						#dump html
						done()
		it 'init_and_wait and a less frequent user', (done)->
			m = api.client.multi()
			m.set [users[0], 'wins'].join('|'), 3
			m.set [users[0], 'losses'].join('|'), 1
			m.set [users[0], 'total_games'].join('|'), 4
			m.exec ->
				api.cache.del users[0]
				api.get_user users[0], (err, user)->
					assert user.wins
					opts = initiator: users[0], type: 'weiqi', players:[users[0]], social: true
					api.init_game opts, (err, gid)->
						assert not err
						api.get_page gid, (err, posts)->
							assert not err
							assert.equal posts[0].type, 'init_game'
							assert.equal posts[0].scenario, 'init_and_wait'
							api.get_refs {blogs:posts, users:_.pluck(users, 'id')}, (err, refs)->
								assert not err
								html = fn blogs:posts, refs:refs
								#dump html
								done()
		it 'init_and_wait and a frequent user', (done)->
			m = api.client.multi()
			m.set [users[0], 'wins'].join('|'), 7
			m.set [users[0], 'losses'].join('|'), 17
			m.set [users[0], 'total_games'].join('|'), 24
			m.hset users[0], 'rate', 1899
			m.exec ->
				api.cache.del users[0]
				api.get_user users[0], (err, user)->
					assert user.wins
					opts = initiator: users[0], type: 'weiqi', players:[users[0]], social: true
					api.init_game opts, (err, gid)->
						assert not err
						api.get_page gid, (err, posts)->
							assert not err
							assert.equal posts[0].type, 'init_game'
							assert.equal posts[0].scenario, 'init_and_wait'
							api.get_refs {blogs:posts, users:_.pluck(users, 'id')}, (err, refs)->
								assert not err
								html = fn blogs:posts, refs:refs
								#dump html
								done()
		
		it 'init_and_start and two new users', (done)->
			opts = initiator: users[0], type: 'weiqi', players:users, social: true
			api.init_game opts, (err, gid)->
				assert not err
				api.get_page gid, (err, posts)->
					assert not err
					assert.equal posts.length, 1
					assert.equal posts[0].type, 'init_game'
					assert.equal posts[0].scenario, 'init_and_start'
					api.get_refs {blogs:posts, users:_.pluck(users, 'id')}, (err, refs)->
						assert not err
						html = fn blogs:posts, refs:refs
						#dump html
						done()
		it 'init_and_start and frequent and less frequent users', (done)->
			m = api.client.multi()
			m.set [users[0], 'wins'].join('|'), 7
			m.set [users[0], 'losses'].join('|'), 17
			m.set [users[0], 'total_games'].join('|'), 24
			m.hset users[0], 'rate', 1899
			m.set [users[1], 'wins'].join('|'), 3
			m.set [users[1], 'losses'].join('|'), 1
			m.set [users[1], 'total_games'].join('|'), 4
			m.exec ->
				opts = initiator: users[0], type: 'weiqi', players:users, social: true
				api.init_game opts, (err, gid)->
					assert not err
					api.get_page gid, (err, posts)->
						assert not err
						assert.equal posts.length, 1
						assert.equal posts[0].type, 'init_game'
						assert.equal posts[0].scenario, 'init_and_start'
						api.get_refs {blogs:posts, users:_.pluck(users, 'id')}, (err, refs)->
							assert not err
							html = fn blogs:posts, refs:refs
							#dump html
							done()