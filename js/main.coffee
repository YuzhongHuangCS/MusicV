'use strict'

(->
	self = this
	# use global context rather than window object
	waveform_array = undefined
	old_waveform = undefined
	objectUrl = undefined
	metaHide = undefined
	micStream = undefined
	# raw waveform data from web audio api
	WAVE_DATA = []
	# normalized waveform data used in visualizations

	# main app/init stuff //////////////////////////////////////////////////////////////////////////
	a = {}

	a.init = ->
		console.log 'a.init fired'
		# globals & state
		self.state = 
			playlist: ['forgot.mp3', 'Animal.wav', 'forgot.mp3', 'Go.mp3', 'Johann_Strauss.mp3', 'Let_Me_Hit_It.mp3', 'Sunrise.mp3', 'The_Mass.mp3']
			width: $(document).width() * 2
			height: $(document).height() * 2
			sliderVal: 50
			canKick: true
			metaLock: false
			vendors: ['-webkit-', '-moz-', '-o-', '']
			drawInterval: 1000 / 24
			then: Date.now()
			trigger: 'circle'
			hud: 1
			active: null
			vizNum: 6
			thumbs_init: [0, 0, 0, 0, 0, 0, 0, 0]
			theme: 4
			currentSong: 0

		h.themeChange(4)
		h.vizChange(6)
		self.context = new (window.AudioContext || window.webkitAudioContext)()

		# append main svg element
		self.svg = d3.select('body').append('svg').attr('id', 'viz').attr('width', state.width).attr('height', state.height)

		a.bind()

		a.keyboard()

		a.loadSound()

		# build svg
		'''
		canvas = document.getElementById('canvas-blended')
		ctx = canvas.getContext('2d')
		ctx.fillStyle = '#FF0000'
		ctx.strokeStyle = '#00FF00'
		ctx.lineWidth = 5
		console.log 'Inintializing'
		'''
		camMotion = CamMotion.Engine()
		camMotion.on 'error', (e) ->
			console.log 'error', e
		camMotion.on 'streamInit', (e) ->
			console.log 'webcam stream initialized', e

		xPos = 0
		yPos = 0
		rPos = 1
		xSpeed = 0
		ySpeed = 0
		rSpeed = 0

		lastX = 1400
		lastY = 600

		camMotion.on 'frame', ->
			point = camMotion.getMovementPoint(true)
			if camMotion.getAverageMovement(point.x - point.r / 2, point.y - point.r / 2, point.r, point.r) > 4
				#	log point
				xSpeed += (point.x - lastX)
				ySpeed += (point.y - lastY)
				#rSpeed *= point.r / 200

				xPos += xSpeed
				yPos += ySpeed
				#rPos *= rSpeed

				$('svg#viz').css('top', yPos)
				$('svg#viz').css('left', xPos)
				#$('svg#viz').css('transform', 'scale(' + rPos + ')')

			xSpeed *= 0.5
			ySpeed *= 0.5
			lastX = point.x
			lastY = point.y
			#rSpeed *= 0.8

		camMotion.start()

	a.bind = ->
		console.log 'a.bind fired'
		click = if Helper.isMobile() then 'touchstart' else 'click'
		$('.menu, .icon-menu').on 'mouseenter touchstart', ->
			h.toggleMenu 'open'

		$('.menu').on 'mouseleave', ->
			h.toggleMenu 'close'

		$('.menu').on click, 'li', ->
			h.vizChange +$(this).attr('viz-num')

		$('.menu').on click, '.clicker', ->
			h.vizChange +$(this).closest('li').attr('viz-num')

		$('.song-metadata').on click, h.songGo
		$('.wrapper').on click, ->
			h.toggleMenu 'close'

		$('.icon-pause').on click, h.togglePlay
		$('.icon-play').on click, h.togglePlay
		$('.icon-forward2').on click, ->
			h.changeSong 'n'

		$('.icon-backward2').on click, ->
			h.changeSong 'p'

		$('.icon-expand').on click, h.toggleFullScreen
		$('.icon-microphone').on click, a.microphone
		$('.icon-question').on click, ->
			h.showModal '#modal-about'

		$('.icon-keyboard2').on click, ->
			h.showModal '#modal-keyboard'

		$('.icon-volume-medium').on click, ->
			audio.muted = if audio.muted == true then false else true

		$('.icon-loop-on').on click, ->
			$(this).find('b').text state.loopText[state.loop % 4]
			h.infiniteChange state.loopDelay[state.loop++ % 4]

		$('.md-close').on click, h.hideModals
		$('.dotstyle').on click, 'li', ->
			h.themeChange $(this).find('a').text()

		$('#slider').on 'input change', ->
			analyser.smoothingTimeConstant = 1 - @value / 100

		$('#slider').on 'change', ->
			$('#slider').blur()

		$('.i').on 'mouseenter', h.tooltipReplace
		$('.i').on 'mouseleave', h.tooltipUnReplace
		$(document).on 'dragenter', h.stop
		$(document).on 'dragover', h.stop
		$(document).on 'drop', h.handleDrop
		$(document).on 'waveform', (e) ->
			#console.log(e.detail);
			waveform_array = e.detail
			#audio = this;

		# hide HUD on idle mouse
		hide = setTimeout ->
			h.hideHUD()
		, 2000

		$('body').on 'touchstart mousemove', ->
			h.showHUD()
			clearTimeout(hide)
			hide = setTimeout ->
				h.hideHUD()
			, 2000

		# update state on window resize
		window.onresize = (event) ->
			h.resize()

		$(document).on 'webkitfullscreenchange mozfullscreenchange fullscreenchange', h.resize
		#http://stackoverflow.com/a/9775411

	a.keyboard = ->
		console.log 'a.keyboard fired'
		Mousetrap.bind 'esc', h.hideModals
		Mousetrap.bind 'space', h.togglePlay
		Mousetrap.bind 'f', h.toggleFullScreen
		Mousetrap.bind 'm', ->
			h.toggleMenu 'toggle'

		Mousetrap.bind 'c', ->
			h.changeSong()

		Mousetrap.bind 'l', ->
			$('.icon-loop-on').trigger 'click'

		Mousetrap.bind 'k', ->
			$('.icon-keyboard2').trigger 'click'

		Mousetrap.bind 'v', ->
			h.changeSong 'n'

		Mousetrap.bind 'x', ->
			h.changeSong 'p'

		Mousetrap.bind '1', ->
			state.trigger = 'circle'

		Mousetrap.bind '3', ->
			state.trigger = 'icosahedron'

		Mousetrap.bind '4', ->
			state.trigger = 'grid'

		Mousetrap.bind '6', ->
			state.trigger = 'spin'

		Mousetrap.bind '7', ->
			state.trigger = 'hexbin'

		Mousetrap.bind '8', ->
			state.trigger = 'voronoi'

		Mousetrap.bind 'up', ->
			h.vizChange state.vizNum - 1

		Mousetrap.bind 'down', ->
			h.vizChange state.vizNum + 1

		Mousetrap.bind 'left', ->
			h.themeChange state.theme - 1

		Mousetrap.bind 'right', ->
			h.themeChange state.theme + 1

	a.loadSound = ->
		console.log 'a.loadSound fired'
		if navigator.userAgent.search('Safari') >= 0 and navigator.userAgent.search('Chrome') < 0
			console.log ' -- sound loaded via ajax request'
			$('.menu-controls').hide()
			a.loadSoundAJAX()
		else
			console.log ' -- sound loaded via html5 audio'
			path = 'mp3/' + state.playlist[0]
			a.loadSoundHTML5 path
			h.readID3 path

	a.loadSoundAJAX = ->
		console.log 'a.loadSoundAJAX fired'
		audio = null
		request = new XMLHttpRequest
		request.open 'GET', 'mp3/' + state.playlist[0], true
		request.responseType = 'arraybuffer'

		request.onload = (event) ->
			data = event.target.response
			a.audioBullshit data


		request.send()

	a.loadSoundHTML5 = (f) ->
		console.log 'a.loadSoundHTML5 fired'
		self.audio = new Audio()
		#audio.remove();
		audio.src = f
		#audio.controls = true;
		#audio.loop = true;
		audio.autoplay = true
		audio.addEventListener 'ended', ->
			h.songEnded()
		, false
		$('#audio_box').empty()
		document.getElementById('audio_box').appendChild audio
		a.audioBullshit()

	a.microphone = ->
		console.log 'a.microphone fired'
		navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia
		if not micStream?
			if navigator.getUserMedia
				navigator.getUserMedia
					audio: true
					video: false
				, (stream) ->
					console.log ' --> audio being captured'
					micStream = stream
					console.log micStream
					src = window.URL.createObjectURL(micStream)
					self.source = context.createMediaStreamSource(micStream)
					source.connect analyser
					analyser.connect context.destination
					audio.pause()
					#audio.src = null;
					return
				, h.microphoneError
			else
				# fallback.
		else
			console.log ' --> turning off'
			micStream.stop()
			micStream = null
			audio.play()
		return

	a.audioBullshit = (data) ->
		# uses web audio api to expose waveform data
		console.log 'a.audioBullshit fired'
		self.analyser = context.createAnalyser()
		#analyser.smoothingTimeConstant = .4; // .8 default
		if navigator.userAgent.search('Safari') >= 0 and navigator.userAgent.search('Chrome') < 0
			self.source = context.createBufferSource()
			source.buffer = context.createBuffer(data, false)
			source.loop = true
			source.noteOn 0
		else
			# https://developer.mozilla.org/en-US/docs/Web/API/AudioContext.createScriptProcessor
			self.source = context.createMediaElementSource(audio)
			# doesn't seem to be implemented in safari :(
			#self.source = context.createMediaStreamSource()
			#self.source = context.createScriptProcessor(4096, 1, 1);  
		source.connect analyser
		analyser.connect context.destination
		a.frameLooper()
		return

	a.findAudio = ->
		# unused.
		console.log 'a.findAudio fired'
		$('video, audio').each ->
			#h.loadSoundHTML5(this.src);
			# if .src?  if playing?
			self.audio = this
			a.audioBullshit()
			return
		#$('object')
		#swf?  SWFObject?
		# can use soundmanager2 -- > http://schillmania.com/projects/soundmanager2/
		# waveformData in sound object gives 256 array.  just multiply by 4?
		return

	a.frameLooper = ->
		#console.log("a.frameLooper fired");
		# recursive function used to update audio waveform data and redraw visualization
		window.requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or window.webkitRequestAnimationFrame or window.msRequestAnimationFrame
		window.requestAnimationFrame a.frameLooper
		now = Date.now()
		delta = now - state.then
		if audio
			$('#progressBar').attr 'style', 'width: ' + audio.currentTime / audio.duration * 100 + '%'
		# some framerate limiting logic -- http://codetheory.in/controlling-the-frame-rate-with-requestanimationframe/
		if delta > state.drawInterval
			state.then = now - delta % state.drawInterval
			# update waveform data
			waveform_array = new Uint8Array(analyser.frequencyBinCount)
			analyser.getByteFrequencyData waveform_array

			#analyser.getByteTimeDomainData(waveform_array);
			# if (c.kickDetect(95)) {
			#   h.themeChange(Math.floor(Math.random() * 6));
			#   h.vizChange(Math.floor(Math.random() * 7));
			# }
			# draw all thumbnails
			r.circle_thumb()
			r.icosahedron_thumb()
			r.grid_thumb()
			r.spin_thumb()
			r.hexbin_thumb()
			# draw active visualizer
			switch state.trigger
				when 'circle', 0
					state.vizNum = 0
					r.circle()
				when 'icosahedron', 2
					state.vizNum = 2
					r.icosahedron()
				when 'grid', 3
					state.vizNum = 3
					r.grid()
				when 'spin', 5
					state.vizNum = 5
					r.spin()
				when 'hexbin', 6
					state.vizNum = 6
					r.hexbin()
				when 'voronoi', 7
					state.vizNum = 7
					r.voronoi()
				else
					state.vizNum = 0
					r.circle()
					break
		return

	self.App = a
	# manipulating/normalizing waveform data ///////////////////////////////////////////////////////
	c = {}

	c.kickDetect = (threshold) ->
		kick = false
		deltas = $(waveform_array).each((n, i) ->
			if !old_waveform
				0
			else
				old_waveform[i] - n
		)
		s = d3.sum(deltas) / 1024
		if s > threshold and state.canKick
			kick = true
			state.canKick = false
			setTimeout (->
				state.canKick = true
				return
			), 5000
		self.old_waveform = waveform_array
		kick

	c.normalize = (coef, offset, neg) ->
		#https://stackoverflow.com/questions/13368046/how-to-normalize-a-list-of-positive-numbers-in-javascript
		coef = coef or 1
		offset = offset or 0
		numbers = waveform_array
		numbers2 = []
		ratio = Math.max.apply(Math, numbers)
		l = numbers.length
		i = 0
		while i < l
			if numbers[i] == 0
				numbers2[i] = 0 + offset
			else
				numbers2[i] = numbers[i] / ratio * coef + offset
			if i % 2 == 0 and neg
				numbers2[i] = -Math.abs(numbers2[i])
			i++
		return numbers2

	c.normalize_binned = (binsize, coef, offset, neg) ->
		numbers = []
		temp = 0
		i = 0
		while i < waveform_array.length
			temp += waveform_array[i]
			if i % binsize == 0
				numbers.push temp / binsize
				temp = 0
			i++
		coef = coef or 1
		offset = offset or 0
		numbers2 = []
		ratio = Math.max.apply(Math, numbers)
		l = numbers.length
		while i < l
			if numbers[i] == 0
				numbers2[i] = 0 + offset
			else
				numbers2[i] = numbers[i] / ratio * coef + offset
			if i % 2 == 0 and neg
				numbers2[i] = -Math.abs(numbers2[i])
			i++
		numbers2

	c.total = ->
		Math.floor d3.sum(waveform_array) / waveform_array.length

	c.total_normalized = ->

	c.bins_select = (binsize) ->
		copy = []
		i = 0
		while i < 500
			if i % binsize == 0
				copy.push waveform_array[i]
			i++
		copy

	c.bins_avg = (binsize) ->
		binsize = binsize or 100
		copy = []
		temp = 0
		while i < waveform_array.length
			temp += waveform_array[i]
			if i % binsize == 0
				copy.push temp / binsize
				temp = 0
			i++
		#console.log(copy);
		copy

	self.Compute = c
	# rendering svg based on normalized waveform data //////////////////////////////////////////////
	r = {}

	r.circle = ->
		if state.active != 'circle'
			state.active = 'circle'
			$('body > svg').empty()
		WAVE_DATA = c.bins_select(70)
		x = d3.scale.linear().domain([
			0
			d3.max(WAVE_DATA)
		]).range([
			0
			420
		])
		slideScale = d3.scale.linear().domain([
			1
			100
		]).range([
			0
			2
		])
		self.bars = svg.selectAll('circle').data(WAVE_DATA, (d) ->
			d
		)
		# bars.attr("r", function(d) { return x(d) + ""; })
		#   .attr('transform', "scale("+slideScale(state.sliderVal)+")")
		#   .attr("cy", function(d, i) { return '50%'; })
		#   .attr("cx", function(d, i) { return '50%'; });
		bars.enter().append('circle').attr('transform', 'scale(' + slideScale(state.sliderVal) + ')').attr('cy', (d, i) ->
			'50%'
		).attr('cx', (d, i) ->
			'50%'
		).attr 'r', (d) ->
			x(d) + ''
		bars.exit().remove()
		return

	r.circle_thumb = ->
		if state.thumbs_init[0] != 'init'
			state.thumbs_init[0] = 'init'
			self.svg_thumb_one = d3.select('#circle').append('svg').attr('width', '100%').attr('height', '100%')
		WAVE_DATA = c.bins_select(200)
		x_t1 = d3.scale.linear().domain([
			0
			d3.max(WAVE_DATA)
		]).range([
			0
			80
		])
		bars_t1 = svg_thumb_one.selectAll('circle').data(WAVE_DATA, (d) ->
			d
		)
		# bars_t1.attr("r", function(d) { return x_t1(d) + ""; })
		#   .attr("cy", function(d, i) { return '50%'; })
		#   .attr("cx", function(d, i) { return '50%'; });
		bars_t1.enter().append('circle').attr('cy', (d, i) ->
			'50%'
		).attr('cx', (d, i) ->
			'50%'
		).attr 'r', (d) ->
			x_t1(d) + ''
		bars_t1.exit().remove()
		return

	r.icosahedron = ->
		# http://bl.ocks.org/mbostock/7782500
		if state.active == 'icosahedron'
			time = Date.now() - self.t0
			xx = c.total() / 100
			style = ''
			i = 0
			while i < state.vendors.length
				style += state.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('body > svg path').attr 'style', style
			#$('body > svg path').attr("style", "transform: skew("+xx+"deg,"+xx+"deg)");
			# 1
			self.projection.rotate [
				time * self.velocity[0]
				time * self.velocity[1]
			]
			self.face.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = self.projection(p)
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			# 2
			self.projection2.rotate [
				time * self.velocity2[0]
				time * self.velocity2[1]
			]
			self.face2.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = self.projection2(p)
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			# 3
			self.projection3.rotate [
				time * self.velocity3[0]
				time * self.velocity3[1]
			]
			self.face3.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = self.projection3(p)
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			return

		state.active = 'icosahedron'
		$('body > svg').empty()
		width = state.width
		height = state.height
		self.velocity = [0.10, 0.005]
		self.velocity2 = [-0.10, -0.05]
		self.velocity3 = [0.10, 0.1]
		self.t0 = Date.now()
		
		# 1
		self.projection = d3.geo.orthographic().scale(height / 2).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg = d3.select('body').append('svg').attr('class', 'isoco1').attr('width', width).attr('height', height)
		self.face = svg.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection))
		)
		# 2
		self.projection2 = d3.geo.orthographic().scale(height / 4).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg2 = d3.select('body').append('svg').attr('class', 'isoco2').attr('width', width).attr('height', height)
		self.face2 = svg2.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection2))
		)
		# 3
		self.projection3 = d3.geo.orthographic().scale(height / 1).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg3 = d3.select('body').append('svg').attr('class', 'isoco3').attr('width', width).attr('height', height)
		self.face3 = svg3.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection3))
		)

	r.icosahedron_thumb = ->
		if state.thumbs_init[2] == 'init'
			xx_t0 = c.total() / 100
			time_t0 = Date.now() - t0_thumb
			style = ''
			i = 0
			while i < state.vendors.length
				style += state.vendors[i] + 'transform: scale(' + xx_t0 + ',' + xx_t0 + '); '
				i++
			$('#icosahedron svg path').attr 'style', style
			projection_thumb.rotate [
				time_t0 * velocity_thumb[0]
				time_t0 * velocity_thumb[1]
			]
			self.face_thumb.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = projection_thumb(p)
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
		state.thumbs_init[2] = 'init'
		width = $('#icosahedron').width()
		height = $('#icosahedron').height()
		self.velocity_thumb = [
			.01
			.05
		]
		self.t0_thumb = Date.now()
		self.projection_thumb = d3.geo.orthographic().scale(height * 1.5).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])

		self.svg_thumb_three = d3.select('#icosahedron').append('svg').attr('width', width).attr('height', height)
		self.face_thumb = svg_thumb_three.selectAll('path').data(h.icosahedronFaces).enter().append('path').each((d) ->
			d.polygon = d3.geom.polygon(d.map(projection_thumb))
		)

	r.grid = (data) ->
		if state.active == 'grid'
			xx = c.total() / 100 + 1
			xx = if xx < 1 then 1 else xx
			xx = if xx > 1.1 then 1.1 else xx
			style = ''
			i = 0
			while i < state.vendors.length
				style += state.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('body > svg path').attr 'style', style
			
			self.projection.rotate([self.λ(self.p), self.φ(self.p)])
			svg.selectAll('path').attr 'd', self.path
			self.p += 5
			#((c.total()/100)*10);
			self.step = Math.floor(c.total() / 100 * 60)
			self.step = if self.step < 5 then 5 else self.step

			self.graticule = d3.geo.graticule()
				.minorStep([self.step, self.step])
				.minorExtent([[-180, -90], [180, 90 + 1e-4]])

			self.grat.datum(self.graticule)
				.attr('class', 'graticule')
				.attr('d', self.path)
			return

		self.p = 0
		state.active = 'grid'
		$('body > svg').empty()
		self.projection = d3.geo.gnomonic()
			.clipAngle(80)
			.scale(500)
		self.path = d3.geo.path().projection(self.projection)
		self.graticule = d3.geo.graticule()
			.minorStep([5, 5])
			.minorExtent([[-180, -90], [180, 90 + 1e-4]])

		# lamda / longitude
		self.λ = d3.scale.linear().domain([0, state.width]).range([-180, 180])

		# phi / latitude
		self.φ = d3.scale.linear()
			.domain([0, state.height])
			.range([90, -90]);
		 
		self.grat = svg.append("path")
			.datum(self.graticule)
			.attr("class", "graticule")
			.attr("d", self.path);

	r.grid_thumb = (data) ->
		width = $('#grid').width()
		height = $('#grid').height()
		if state.thumbs_init[3] == 'init'
			xx = c.total() / 100 + 1
			xx = if xx == 1 then 0 else xx
			#   xx = (xx>1.4) ? 1.4 : xx;
			style = ''
			i = 0
			while i < state.vendors.length
				style += state.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('#grid svg path').attr 'style', style
			# step = Math.floor((c.total()/100)*5);
			# step = (step<1) ? 1 : step;
			# graticule = d3.geo.graticule()
			#   .minorStep([step, step])
			#   .minorExtent([[-180, -90], [180, 90 + 1e-4]]);
			# grat.datum(graticule)
			#   .attr("class", "graticule")
			#   .attr("d", path);
			return
		state.thumbs_init[3] = 'init'
		$('#grid svg').empty()
		projection = d3.geo.gnomonic()
			.clipAngle(80)
			#.scale(50)

		path = d3.geo.path()
			.projection(projection);
		
		graticule = d3.geo.graticule()
			.minorStep([2, 2])
			.minorExtent([[-180, -90], [180, 90 + 1e-4]]);
 
		svg_thumb_four = d3.select("#grid").append("svg")
			.attr("width", width)
			.attr("height", height);

		grat = svg_thumb_four.append("path")
			.datum(graticule)
			.attr("class", "graticule")
			.attr("d", path);

	r.spin = ->
		if state.active == 'spin'
			WAVE_DATA = c.total() * 2
			#WAVE_DATA = c.normalize_binned(200,1000,10);
			$c = $('body > svg circle')
			$c.attr 'style', 'stroke-width: ' + WAVE_DATA * 4 + 'px'
			$c.attr 'stroke-dashoffset', WAVE_DATA + 'px'
			$c.attr 'stroke-dasharray', WAVE_DATA / 6 + 'px'
			$c.attr 'opacity', WAVE_DATA / 2200
			return
		state.active = 'spin'
		$('body > svg').empty()
		elems = [
			{
				id: 'c1'
				radius: 300
			}
			{
				id: 'c4'
				radius: 10
			}
			{
				id: 'c2'
				radius: 100
			}
			{
				id: 'c3'
				radius: 50
			}
		]
		bars = svg.selectAll("circle").data elems, (d,i)->
			return i

		bars.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', (d) ->
			d.id
		).attr 'r', (d) ->
			d.radius + ''
		bars.exit().remove()

	r.spin_thumb = ->
		if state.thumbs_init[5] == 'init'
			WAVE_DATA = c.total() * 2
			#WAVE_DATA = c.normalize_binned(200,1000,10);
			$c = $('#spin svg circle')
			$c.attr 'style', 'stroke-width: ' + WAVE_DATA * 4 + 'px'
			$c.attr 'stroke-dashoffset', WAVE_DATA + 'px'
			$c.attr 'stroke-dasharray', WAVE_DATA / 6 + 'px'
			$c.attr 'opacity', WAVE_DATA / 2200
			return

		$('#spin svg').empty()
		state.thumbs_init[5] = 'init'
		self.svg_thumb_six = d3.select('#spin').append('svg').attr('width', '100%').attr('height', '100%')
		elems = [
			{
				id: 'c4'
				radius: 10
			}
			{
				id: 'c3'
				radius: 50
			}
		]
		bars_t6 = svg_thumb_six.selectAll("circle").data elems, (d,i)->
			return i

		bars_t6.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', (d) ->
			d.id
		).attr 'r', (d) ->
			d.radius + ''
		bars_t6.exit().remove()

	r.hexbin = ->
		# http://bl.ocks.org/mbostock/4248145 
		# http://bl.ocks.org/mbostock/4248146
		$('body > svg').empty()
		if state.active != 'hexbin'
			randomX = d3.random.normal(state.width / 2, 2100)
			self.ps = d3.range(1024).map ->
					return randomX()

		state.active = 'hexbin'
		points = d3.zip(self.ps, c.normalize(state.height, 0))
		#randomY = d3.random.normal(state.height / 2, 900)
		#points = d3.range(1000).map ->
		#   return [randomX(), randomY()]
		color = d3.scale.linear()
			.domain([0, 20])
			.range([$('.dotstyle li.current a').css('background-color'), $('.dotstyle li.current a').css('background-color')])
			.interpolate(d3.interpolateLab);

		hexbin = d3.hexbin()
			.size([state.width, state.height])
			.radius(50);

		radius = d3.scale.linear()
			.domain([0, 20])
			.range([3, 200]);

		svg.append('g').selectAll('.hexagon').data(hexbin(points)).enter().append('path').attr('class', 'hexagon').attr('id', 'hexx').attr('d', (d) ->
			hexbin.hexagon radius(d.length)
		).attr('transform', (d) ->
			'translate(' + d.x + ',' + d.y + ')'
		).style('fill', (d) ->
			color d.length
		).style 'opacity', (d) ->
			if radius(d.length) / 180 > 0.6
				return 0;
			else
				if (radius(d.length)/180 > 0.4)
					if (Math.random()>0.1)
						return 0;
					else
						return 0.25+(radius(d.length)/180)*1.8
				else
					return 0.25+(radius(d.length)/180)*1.8;

	r.hexbin_thumb = ->
		# http://bl.ocks.org/mbostock/4248145 
		# http://bl.ocks.org/mbostock/4248146
		width = $('#hexbin').width()
		height = $('#hexbin').height()
		if state.thumbs_init[6] != 'init'
			self.svg_thumb_seven = d3.select('#hexbin').append('svg')
				.attr('width', '100%')
				.attr('height', '100%')

			state.thumbs_init[6] = 'init'
			randomX_t7 = d3.random.normal(width / 2, 50)
			self.ps_t7 = d3.range(1024).map ()->
				return randomX_t7()
			#console.log ps_t7

		$('#hexbin svg').empty()
		points_t7 = d3.zip(self.ps_t7, c.normalize(height*1.5, -20))

		color_t7 = d3.scale.linear()
			.domain([0, 50])
			.range(["black", "white"])
			.interpolate(d3.interpolateLab);

		hexbin_t7 = d3.hexbin()
			.size([width, height])
			.radius(15);

		radius_t7 = d3.scale.linear()
			.domain([0, 10])
			.range([0, 15]);

		svg_thumb_seven.append('g')
			.selectAll('.hexagon')
				.data(hexbin_t7(points_t7))
			.enter().append('path')
				.attr('class', 'hexagon')
				.attr('d', (d) ->
					hexbin_t7.hexagon 15
				).attr('transform', (d) ->
					'translate(' + d.x + ',' + d.y + ')'
				).style 'fill', (d) ->
					color_t7(d.length)

	r.voronoi = ->
		# http://bl.ocks.org/mbostock/4060366

		redraw = ->
			vertices = d3.range(100).map (d)->
				return [Math.random() * width, Math.random() * height];

			path = path.data(voronoi(vertices), polygon)
			path.exit().remove()
			path.enter().append('path').attr('class', (d, i) ->
				'q' + i % 9 + '-9'
			).attr 'd', polygon
			path.order()

		polygon = (d) ->
			'M' + d.join('L') + 'Z'

		if state.active == 'voronoi'
			redraw()
			return
		state.active = 'voronoi'
		width = state.width
		height = state.height
		vertices = d3.range(100).map (d)->
		  return [Math.random() * width, Math.random() * height];

		voronoi = d3.geom.voronoi()
			.clipExtent([[0, 0], [width, height]]);

		svg = d3.select("body").append("svg")
			.attr("width", width)
			.attr("height", height);

		path = svg.append("g").selectAll("path");

		svg.selectAll('circle').data(vertices.slice(1)).enter().append('circle').attr('transform', (d) ->
			'translate(' + d + ')'
		).attr 'r', 1.5
		redraw()

	self.Render = r
	# helper methods ///////////////////////////////////////////////////////////////////////////////
	h = {}

	h.toggleMenu = (x) ->
		console.log 'h.toggleMenu'
		if x == 'toggle'
			x = if $('.menu').hasClass('menu-open') then 'close' else 'open'
		if x == 'open'
			$('.menu').addClass 'menu-open'
			$('.icon-menu').addClass 'fadeOut'
			#$("body > svg").attr("class", "svg-open");
		else
			$('.menu').removeClass 'menu-open'
			#$("body > svg").attr("class", "svg-closed");
		return

	h.toggleFullScreen = ->
		console.log 'h.toggleFullScreen fired'
		# thanks mdn
		if !document.fullscreenElement and !document.mozFullScreenElement and !document.webkitFullscreenElement and !document.msFullscreenElement
			# current working methods
			$('.icon-expand').addClass 'icon-contract'
			if document.documentElement.requestFullscreen
				document.documentElement.requestFullscreen()
			else if document.documentElement.msRequestFullscreen
				document.documentElement.msRequestFullscreen()
			else if document.documentElement.mozRequestFullScreen
				document.documentElement.mozRequestFullScreen()
			else if document.documentElement.webkitRequestFullscreen
				document.documentElement.webkitRequestFullscreen Element.ALLOW_KEYBOARD_INPUT
		else
			$('.icon-expand').removeClass 'icon-contract'
			if document.exitFullscreen
				document.exitFullscreen()
			else if document.msExitFullscreen
				document.msExitFullscreen()
			else if document.mozCancelFullScreen
				document.mozCancelFullScreen()
			else if document.webkitExitFullscreen
				document.webkitExitFullscreen()
		return

	h.hideHUD = ->
		return if $('#mp3_player:hover') or $('.dotstyle:hover') or $('.slider:hover') or $('.icon-expand:hover') or $('.icon-github2:hover') or $('.icon-loop-on:hover') or $('.icon-question:hover') or $('.icon-keyboard2:hover') or $('.song-metadata:hover') or $('.icon-forward2:hover') or $('.icon-backward2:hover') or $('.icon-pause:hover') or $('.schover:hover')

		$('#mp3_player').addClass 'fadeOut'
		$('.icon-menu').addClass 'fadeOut'
		$('.menu-wide').addClass 'fadeOut'
		$('.menu').addClass 'fadeOut'
		$('.menu-controls').addClass 'fadeOut'
		$('#progressBar').addClass 'fadeOut'
		$('html').addClass 'noCursor'
		if state.metaLock == false
			$('.song-metadata').removeClass 'show-meta'
		state.hud = 0

	h.showHUD = ->
		$('#mp3_player').removeClass 'fadeOut'
		$('.icon-menu').removeClass 'fadeOut'
		$('.menu-wide').removeClass 'fadeOut'
		$('.menu').removeClass 'fadeOut'
		$('.menu-controls').removeClass 'fadeOut'
		$('#progressBar').removeClass 'fadeOut'
		$('html').removeClass 'noCursor'
		$('.song-metadata').addClass 'show-meta'
		state.hud = 1

	h.showModal = (id) ->
		if $(id).hasClass('md-show')
			h.hideModals()
		if $('.md-show').length > 0
			h.hideModals()
		$(id).addClass 'md-show'

	h.hideModals = ->
		$('.md-modal').removeClass 'md-show'

	h.resize = ->
		console.log 'h.resize fired'
		state.width = $(window).width() * 2
		state.height = $(window).height() * 2
		state.active = state.trigger
		$('body > svg').attr('width', state.width).attr 'height', state.height
		full = document.fullscreen or document.webkitIsFullScreen or document.mozFullScreen
		if !full
			$('.icon-expand').removeClass 'icon-contract'

	h.stop = (e) ->
		e.stopPropagation()
		e.preventDefault()

	h.handleDrop = (e) ->
		console.log 'h.handleDrop fired'
		h.stop e
		#if (window.File && window.FileReader && window.FileList && window.Blob) {
		URL.revokeObjectURL objectUrl
		file = e.originalEvent.dataTransfer.files[0]
		if !file.type.match(/audio.*/)
			console.log 'not audio file'

		h.readID3 file
		objectUrl = URL.createObjectURL(file)
		a.loadSoundHTML5 objectUrl


	h.readID3 = (file) ->
		console.log 'h.readID3 fired'
		$('.song-metadata').html ''
		if typeof file == 'string'
			ID3.loadTags audio.src, ->
				tags = ID3.getAllTags(audio.src)
				h.renderSongTitle tags
		else
			ID3.loadTags file.urn or file.name, (->
				tags = ID3.getAllTags(file.urn or file.name)
				tags.dragged = true
				h.renderSongTitle tags
				if 'picture' in tags
					image = tags.picture
					base64String = ''
					i = 0
					while i < image.data.length
						base64String += String.fromCharCode(image.data[i])
						i++
					#console.log("data:" + image.format + ";base64," + window.btoa(base64String));
					#$("art").src = "data:" + image.format + ";base64," + window.btoa(base64String);
					#$("art").style.display = "block";
				else
					#console.log("nope.");
					#$("art").style.display = "none";
				return
			), dataReader: FileAPIReader(file)
		return

	h.togglePlay = ->
		if audio and audio.paused == false then audio.pause() else audio.play()
		$('.icon-pause').toggleClass 'icon-play'
		return

	h.songEnded = ->
		console.log 'h.songEnded fired'
		h.changeSong 'n'
		return

	h.changeSong = (direction) ->
		console.log 'h.changeSong fired'
		totalTracks = state.playlist.length
		if direction == 'n'
			state.currentSong = state.currentSong + 1
		else if direction == 'p'
			if audio.currentTime < 3
				state.currentSong = if state.currentSong <= 0 then state.currentSong + totalTracks - 1 else state.currentSong - 1
			else
				audio.currentTime = 0
				$('.icon-pause').removeClass 'icon-play'
				return
		else
			state.currentSong = Math.floor(Math.random() * totalTracks)

		if audio
			audio.src = 'mp3/' + state.playlist[Math.abs(state.currentSong) % state.playlist.length]
			h.readID3 audio.src
		$('.icon-pause').removeClass 'icon-play'

	h.renderSongTitle = (obj) ->
		console.log 'h.renderSongTitle fired'

		# id3?
		prettyTitle = '"' + obj.title + '" by <b>' + obj.artist + '</b>'
		#  on <i>'+tags.album+'</i>
		trackNum = Math.abs(state.currentSong) % state.playlist.length
		if state.playlist.length > 1 and !obj.dragged
			prettyTitle += ' [' + trackNum + 1 + '/' + state.playlist.length + ']'
		$('.song-metadata').html prettyTitle
		#$('.song-metadata').attr('data-go', state.playListLinks[trackNum]);
		$('.song-metadata').addClass 'show-meta'
		state.metaLock = true
		clearTimeout metaHide
		# in 3 seconds, remove class unless lock
		metaHide = setTimeout ->
			state.metaLock = false
			if state.hud == 0
				$('.song-metadata').removeClass 'show-meta'
		, 3000

	h.tooltipReplace = ->
		console.log 'h.tooltipReplace fired'
		text = $(this).attr('data-hovertext')
		console.log text
		if text?
			state.hoverTemp = $('.song-metadata').html()
			$('.song-metadata').html text

	h.tooltipUnReplace = ->
		console.log 'h.tooltipUnReplace fired'
		if state.hoverTemp?
			$('.song-metadata').html state.hoverTemp
			state.hoverTemp = null
		return

	h.songGo = ->
		console.log 'h.songGo fired.'
		if !$(this).attr('data-go')
			return false
		audio.pause()
		$('.icon-pause').removeClass 'icon-play'
		window.open $(this).attr('data-go'), '_blank'
		return

	h.themeChange = (n) ->
		n = +n
		n = if n < 0 then 5 else n
		n = if n > 5 then 0 else n
		state.theme = n
		console.log 'h.themeChange:' + n
		name = 'theme_' + n
		$('html').attr 'class', name
		$('.dotstyle li.current').removeClass 'current'
		$('.dotstyle li:eq(' + n + ')').addClass 'current'

	h.vizChange = (n) ->
		n = if n < 0 then 6 else n
		n = if n > 6 then 0 else n
		console.log 'h.vizChange:' + n
		state.trigger = n
		$('.menu li.active').removeClass 'active'
		$('.menu li[viz-num="' + n + '"]').addClass 'active'

	h.infiniteChange = (toggle) ->
		console.log 'h.infiniteChange fired: ' + toggle
		clearInterval state.changeInterval
		state.changeInterval = setInterval ->
			h.themeChange Math.floor(Math.random() * 6)
			h.vizChange Math.floor(Math.random() * 8)
		, toggle
		if not toggle
			clearInterval state.changeInterval

	h.icosahedronFaces = (slide) ->
		slide = slide or 180
		faces = []
		y = Math.atan2(1, 2) * slide / Math.PI
		x = 0
		while x < 360
			faces.push(
				[[x +  0, -90], [x +  0,  -y], [x + 72,  -y]],
				[[x + 36,   y], [x + 72,  -y], [x +  0,  -y]],
				[[x + 36,   y], [x +  0,  -y], [x - 36,   y]],
				[[x + 36,   y], [x - 36,   y], [x - 36,  90]]
			)
			x += 72
		faces

	h.degreesToRads = (n) ->
		d3.scale.linear().domain([
			0
			360
		]).range([
			0
			2 * Math.PI
		]) this

	h.microphoneError = (e) ->
		# user clicked not to let microphone be used
		console.log e

	h.isMobile = ->
		# returns true if user agent is a mobile device
		return /iPhone|iPod|iPad|Android|BlackBerry/.test navigator.userAgent

	self.Helper = h

).call(this)

$(document).ready(App.init)
