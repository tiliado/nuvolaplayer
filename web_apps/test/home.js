var Nuvola = {}
/**
 * Creates HTML text node
 * @param text  text of the node
 * @return      new text node
 */
Nuvola.makeText = function (text) {
  return document.createTextNode(text)
}

/**
 * Creates HTML element
 * @param name          element name
 * @param attributes    element attributes (optional)
 * @param text          text of the element (optional)
 * @return              new HTML element
 */
Nuvola.makeElement = function (name, attributes, text) {
  var elm = document.createElement(name)
  attributes = attributes || {}
  for (var key in attributes) {
    elm.setAttribute(key, attributes[key])
  }
  if (text !== undefined && text !== null) {
    elm.appendChild(Nuvola.makeText(text))
  }
  return elm
}

var RATING_TEXT = ['bad', '-', 'good']

var Player = function () {
  this.playlist = document.getElementById('playlist')
  var self = this

  for (var i = 0; i < Player.songs.length; i++) {
    var song = Player.songs[i]
    var tr = Nuvola.makeElement('tr')
    tr.appendChild(Nuvola.makeElement('td', null, i))
    tr.appendChild(Nuvola.makeElement('td', null, song.name))
    tr.appendChild(Nuvola.makeElement('td', null, song.artist))
    tr.appendChild(Nuvola.makeElement('td', null, song.album))
    tr.appendChild(Nuvola.makeElement('td', null, RATING_TEXT[song.rating + 1]))
    tr.setAttribute('data-i', i)
    tr.onclick = function () {
      self.setPos(this.getAttribute('data-i') * 1)
      self.play()
    }
    this.playlist.appendChild(tr)
  }

  this.elm = {
    pp: document.getElementById('pp'),
    prev: document.getElementById('prev'),
    next: document.getElementById('next'),
    status: document.getElementById('status'),
    timer: document.getElementById('timer'),
    nowplaying: document.getElementById('nowplaying'),
    track: document.getElementById('track'),
    artist: document.getElementById('artist'),
    album: document.getElementById('album'),
    rating: document.getElementById('rating'),
    progressbar: document.getElementById('progressbar'),
    progressmark: document.getElementById('progressmark'),
    progresstext: document.getElementById('progresstext'),
    timeelapsed: document.getElementById('timeelapsed'),
    timetotal: document.getElementById('timetotal'),
    volume: document.getElementById('volume')
  }

  this.elm.progresstext.onclick = function (event) {
    self._onProgressBarClicked(this, event)
  }

  this.elm.prev.disabled = true
  this.elm.next.disabled = true
  this.setStatus(0)
  this.pos = -1
  this.timer = -1
  this.timerId = 0
}

Player.songs =
[
  {
    name: 'Surrender',
    artist: 'Billy Talent',
    album: 'Billy Talent II',
    rating: 1,
    time: 25
  },
  {
    name: 'Holiday',
    artist: 'Green Day',
    album: 'American Idiot',
    rating: -1,
    time: 8
  },
  {
    name: 'Fallen Leaves',
    artist: 'Billy Talent',
    album: 'Billy Talent II',
    rating: 0,
    time: 10
  },
  {
    name: 'Boten Anna',
    artist: 'Basshunter',
    album: 'LOL',
    rating: 1,
    time: 5
  },
  {
    name: 'Set Your Monster Free',
    artist: 'Quiet Company',
    album: 'We Are All Where We Belong',
    rating: 1,
    time: 5
  },
  {
    name: 'Come Home',
    artist: 'Morandi',
    album: 'Mindfields',
    rating: -1,
    time: 5
  },
  {
    name: 'Dancer in the Dark',
    artist: 'The Rasmus',
    album: 'Hide From the Sun',
    rating: -1,
    time: 5
  },
  {
    name: 'Have You Ever',
    artist: 'The Offspring',
    album: 'Americana',
    rating: 0,
    time: 5
  },
  {
    name: 'Pushing Me Away',
    artist: 'Linkin Park',
    album: 'Hybrid Theory',
    rating: 0,
    time: 5
  }
]

Player.statuses = ['Not playing', 'Playing', 'Paused']
Player.STOPPED = 0
Player.PLAYING = 1
Player.PAUSED = 2

Player.prototype.setStatus = function (status) {
  this.status = status
  this.elm.status.innerText = Player.statuses[status]
  this.elm.pp.innerText = status === 1 ? 'Pause' : 'Play'
}

Player.prototype.setPos = function (pos) {
  this.pos = pos
  var rows = document.querySelectorAll('#playlist tr')
  for (var i = 0; i < rows.length; i++) {
    rows[i].className = i === pos ? 'playing' : ''
  }

  this.elm.prev.disabled = pos <= 0
  this.elm.next.disabled = pos < 0 || pos === Player.songs.length - 1
  this.timer = 5

  if (pos >= 0) {
    var track = Player.songs[pos]
    this.timer = track.time
    this.elm.timer.innerText = this.timer
    this.elm.track.innerText = track.name
    this.elm.artist.innerText = track.artist
    this.elm.album.innerText = track.album
    this.elm.rating.innerText = RATING_TEXT[track.rating + 1]
    this.elm.nowplaying.style.display = 'inline'
    this.elm.progressbar.style.display = 'block'
    var totaltime = track.time < 10 ? '0' + track.time : track.time
    this.elm.timetotal.innerText = '00:' + totaltime
    this.elm.timeelapsed.innerText = '00:00'
    this.elm.progressmark.style.width = 0 + '%'
  } else {
    this.elm.timer.innerText = ''
    this.elm.track.innerText = ''
    this.elm.artist.innerText = ''
    this.elm.album.innerText = ''
    this.elm.nowplaying.style.display = 'none'
    this.elm.progressbar.style.display = 'none'
  }
}

Player.prototype.play = function () {
  if (this.status === Player.PAUSED) {
    this.setStatus(Player.PLAYING)
    this.timerId = setTimeout(this.tick.bind(this), 1000)
  } else if (this.status === Player.STOPPED) {
    if (this.pos < 0) {
      this.setPos(0)
    }
    this.setStatus(Player.PLAYING)
    this.startTimer()
  }
}

Player.prototype.pause = function () {
  if (this.status === Player.PLAYING) {
    this.setStatus(Player.PAUSED)
    clearTimeout(this.timerId)
    this.timerId = 0
  }
}

Player.prototype.togglePlay = function () {
  if (this.status === Player.PLAYING) {
    this.pause()
  } else {
    this.play()
  }
}

Player.prototype.next = function () {
  if (this.pos < Player.songs.length - 1) {
    this.setPos(this.pos + 1)
    return true
  }
  return false
}

Player.prototype.prev = function () {
  if (this.pos > 0) {
    this.setPos(this.pos - 1)
    return true
  }
  return false
}

Player.prototype.startTimer = function () {
  if (this.timer <= 0) { this.timer = 5 }
  this.tick()
}

Player.prototype.tick = function () {
  if (this.timer > 0) {
    this.elm.timer.innerText = this.timer--
    this.updateProgressBar()
    this.timerId = setTimeout(this.tick.bind(this), 1000)
  } else {
    if (this.next()) { this.startTimer() } else { this.reset() }
  }
}

Player.prototype.reset = function () {
  this.setPos(-1)
  this.setStatus(0)
  this.elm.timer.innerText = ''
  this.timerId = 0
}

Player.prototype.updateProgressBar = function () {
  var total = Player.songs[this.pos].time
  var elapsed = total - this.timer
  this.elm.progressmark.style.width = (elapsed / total * 100) + '%'
  elapsed = elapsed < 10 ? '0' + elapsed : elapsed
  this.elm.timeelapsed.innerText = '00:' + elapsed
}

Player.prototype._onProgressBarClicked = function (button, event) {
  if (event.button === 0) {
    var x = event.clientX
    var rect = button.getBoundingClientRect()
    var pos = (x - rect.left) / rect.width
    var total = Player.songs[this.pos].time
    this.timer = total - Math.round(pos * total)
    this.updateProgressBar()
  }
}

window.player = new Player()
