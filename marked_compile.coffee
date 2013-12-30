marked = require 'marked'
fs = require 'fs'
ndir = require 'ndir'
_ = require 'underscore'

ndir.walk 'views/docs', (dirpath, files)->
	_.each files, (f)->
		if /\.md$/.test(f[0])
			html = marked.parser marked.lexer fs.readFileSync(f[0]).toString()
			fs.writeFileSync f[0].replace(/\.md$/, '.html'), html