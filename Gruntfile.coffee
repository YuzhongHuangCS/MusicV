module.exports = (grunt)->
	grunt.initConfig
		jade:
			compile:
				files:
					'index.html': ['index.jade']
		coffee:
			compile:
				files:
					'js/main_new.js': 'js/main.coffee'
		watch:
			jade:
		    	files: ['index.jade'],
		    	tasks: ['jade']
		    coffee:
		    	files: ['js/main.coffee']
		    	tasks: ['coffee']

	grunt.loadNpmTasks('grunt-contrib-jade');
	grunt.loadNpmTasks('grunt-contrib-coffee');
	grunt.loadNpmTasks('grunt-contrib-watch');

	grunt.registerTask('default', ['jade', 'coffee']);
	grunt.registerTask('develop', ['watch']);
