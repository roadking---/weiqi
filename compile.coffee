exec = require('child_process').exec

exec "coffee -c -o public/js public_js", (error, stdout, stderr)->
	console.log('stdout: ' + stdout)
	console.log('stderr: ' + stderr)