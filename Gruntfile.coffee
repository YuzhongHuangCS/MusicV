module.exports = (grunt)->
	grunt.initConfig
		jade:
			compile:
				files:
					'index.html': ['index.jade']
		watch:
			jade:
		    	files: ['index.jade'],
		    	tasks: ['jade']

	grunt.loadNpmTasks('grunt-contrib-jade')
	grunt.loadNpmTasks('grunt-contrib-watch')

	grunt.registerTask('default', ['jade'])
	grunt.registerTask('develop', ['watch'])
