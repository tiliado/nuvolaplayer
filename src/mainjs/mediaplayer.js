/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

require('prototype')
require('signals')
require('notification')
require('launcher')
require('actions')
require('mediakeys')
require('storage')
require('browser')
require('core')
require('gettext')

// Translations
var _ = Nuvola.Translate.gettext
var C_ = Nuvola.Translate.pgettext

/**
 * @enum Base media player @link{Actions|actions}
 *
 * @since Nuvola 4.13: `REPEAT` and `SHUFFLE` actions were added.
 */
var PlayerAction = {
    /**
     * Start playback
     */
  PLAY: 'play',
    /**
     * Toggle playback (play/pause)
     */
  TOGGLE_PLAY: 'toggle-play',
    /**
     * Pause playback
     */
  PAUSE: 'pause',
    /**
     * Stop playback
     */
  STOP: 'stop',
    /**
     * Skip to next track
     */
  PREV_SONG: 'prev-song',
    /**
     * Skip to previous track
     */
  NEXT_SONG: 'next-song',
    /**
     * Show playback notification
     */
  PLAYBACK_NOTIFICATION: 'playback-notification',
    /**
     * Seek to a new position
     */
  SEEK: 'seek',
    /**
     * Change volume
     */
  CHANGE_VOLUME: 'change-volume',
  /**
   * Repeat status
   */
  REPEAT: 'repeat',
  /**
   * Shuffle status.
   */
  SHUFFLE: 'shuffle'
}

/**
 * @enum Media player repeat status
 *
 * @since Nuvola 4.13
 */
var PlayerRepeat = {
  /**
   * The playback will stop when there are no more tracks to play.
   */
  NONE: 0,
  /**
   * The current track will start again from the beginning once it has finished playing.
   */
  TRACK: 1,
  /**
   * The playback loops through a list of tracks.
   */
  PLAYLIST: 2
}

/**
 * @enum Media player playback states
 */
var PlaybackState = {
    /**
     * Track is not playing nor paused.
     */
  UNKNOWN: 0,
    /**
     * Playback is paused.
     */
  PAUSED: 1,
    /**
     * Track is playing.
     */
  PLAYING: 2
}

var repeatOptions = [
    // stateId, label, mnemo_label, icon, keybinding
    [PlayerRepeat.NONE, _('No repeat'), null, null, null, null],
    [PlayerRepeat.TRACK, _('Repeat track'), null, null, null, null],
    [PlayerRepeat.PLAYLIST, _('Repeat playlist'), null, null, null, null]
]

// New key
var RUN_IN_BACKGROUND = 'player.run_in_background'
// Deprecated key - for backward compatibility
var BACKGROUND_PLAYBACK = 'player.background_playback'

var RUN_IN_BACKGROUND_OPTIONS = [
    ['always', C_('Background playback', 'Always')],
    ['playing', C_('Background playback', 'When song is playing')],
    ['never', C_('Background playback', 'Never')]
]

var COMPONENT_NOTIFICATIONS = 'notifications'
var COMPONENTS_TO_ACTIVATE = ['mpris', 'lyrics', 'mediakeys', 'scrobbler']

/**
 * Media player controller.
 */
var MediaPlayer = Nuvola.$prototype(null, Nuvola.SignalsMixin)

/**
 * Initializes media player
 */
MediaPlayer.$init = function () {
  Nuvola.mediaPlayer = this

    /**
     * Emitted when a rating is set.
     *
     * Note that rating has to be enabled first with a method @link{MediaPlayer.setCanRate}.
     *
     * @since API 3.1
     *
     * @param Number rating    Ratting from `0.0` to `1.0`.
     */
  this.addSignal('RatingSet')

  this._appRunner = false
  this._state = null
  this._artworkFile = null
  this._canGoPrev = null
  this._canGoNext = null
  this._canPlay = null
  this._canPause = null
  this._canRate = null
  this._canSeek = null
  this._canChangeVolume = null
  this._extraActions = []
  this._artworkLoop = 0
  this._baseActions = [
    PlayerAction.TOGGLE_PLAY, PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG,
    PlayerAction.SHUFFLE
  ]
  this._repeatActions = []
  for (var i = 0; i <= PlayerRepeat.PLAYLIST; i++) {
    this._repeatActions.push(PlayerAction.REPEAT + '::' + i)
  }
  this._notification = null
  this._trackPosition = 0
  this._volume = 1.0
  Nuvola.core.connect('InitAppRunner', this)
  Nuvola.core.connect('InitWebWorker', this)
}

/**
 * Set info about currently playing track.
 *
 * If track info is same as in the previous call, this method does nothing.
 *
 * @param String|null track.title          track title
 * @param String|null track.artist         track artist
 * @param String|null track.album          track album
 * @param String|null track.artLocation    URL of album/track artwork
 * @param double|null track.rating         track rating from `0.0` to `1.0`. *This item is ignored prior API 3.1.*
 * @param double|null track.length         track length as a string (`HH:MM:SS.xxx`, e.g. `1:25.54`) or number of microseconds. *This item is ignored prior API 4.5.*
 */
MediaPlayer.setTrack = function (track) {
  track.length = Nuvola.parseTimeUsec(track.length)
  var changed = Nuvola.objectDiff(this._track, track)

  if (!changed.length) { return }

  this._track = Object.assign({}, track)

  if (!track.artLocation) { this._artworkFile = null }

  if (Nuvola.inArray(changed, 'artLocation') && track.artLocation) {
    this._artworkFile = null
    var artworkId = this._artworkLoop++
    if (this._artworkLoop > 9) { this._artworkLoop = 0 }
    Nuvola.browser.downloadFileAsync(track.artLocation, 'player.artwork.' + artworkId, this._onArtworkDownloaded.bind(this), changed)
    this._sendDevelInfo()
  } else {
    this._updateTrackInfo(changed)
  }
}

/**
 * Set current playback position
 *
 * If the current position is the same as the previous one, this method does nothing.
 *
 * @since API 4.5
 *
 * @param String|Number position    the current track position as a string (`HH:MM:SS.xxx`, e.g. `1:25.54`) or number of microseconds.
 */
MediaPlayer.setTrackPosition = function (position) {
  position = Nuvola.parseTimeUsec(position)
  if (this._trackPosition !== position) {
    this._trackPosition = position
    Nuvola._callIpcMethodVoid('/nuvola/mediaplayer/set-track-position', [position])
  }
}

/**
 * Update current volume
 *
 * If the current volume is the same as the previous one, this method does nothing.
 *
 * @since API 4.5
 *
 * @param Number volume    the current volume from 0.0 to 1.0.
 */
MediaPlayer.updateVolume = function (volume) {
  volume = (volume || 0.0) * 1
  if (this._volume !== volume) {
    this._volume = volume
    Nuvola._callIpcMethodVoid('/nuvola/mediaplayer/update-volume', [volume])
  }
}

/**
 * Set current playback state
 *
 * If the current state is same as the previous one, this method does nothing.
 *
 * @param PlaybackState state    current playback state
 */
MediaPlayer.setPlaybackState = function (state) {
  if (this._state !== state) {
    this._state = state
    Nuvola.actions.setEnabled(PlayerAction.PLAYBACK_NOTIFICATION, this._state !== PlaybackState.UNKNOWN)
    this._setActions()
    this._updateTrackInfo(['state'])
  }
}

MediaPlayer._setFlag = function (name, state) {
  Nuvola._callIpcMethodVoid('/nuvola/mediaplayer/set-flag', [name, state])
}

/**
 * Set whether it is possible to go to the next track
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @param Boolean canGoNext    true if the "go to next track" button is active
 */
MediaPlayer.setCanGoNext = function (canGoNext) {
  if (this._canGoNext !== canGoNext) {
    this._canGoNext = canGoNext
    Nuvola.actions.setEnabled(PlayerAction.NEXT_SONG, !!canGoNext)
    this._setFlag('can-go-next', !!canGoNext)
    this._showNotification()
    this._sendDevelInfo()
  }
}

/**
 * Set whether it is possible to go to the previous track
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @param Boolean canGoPrev    true if the "go to previous track" button is active
 */
MediaPlayer.setCanGoPrev = function (canGoPrev) {
  if (this._canGoPrev !== canGoPrev) {
    this._canGoPrev = canGoPrev
    Nuvola.actions.setEnabled(PlayerAction.PREV_SONG, !!canGoPrev)
    this._setFlag('can-go-previous', !!canGoPrev)
    this._showNotification()
    this._sendDevelInfo()
  }
}

/**
 * Set whether it is possible to start playback
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @param Boolean canPlay    true if the "play" button is active
 */
MediaPlayer.setCanPlay = function (canPlay) {
  if (this._canPlay !== canPlay) {
    this._canPlay = canPlay
    Nuvola.actions.setEnabled(PlayerAction.PLAY, !!canPlay)
    Nuvola.actions.setEnabled(PlayerAction.TOGGLE_PLAY, !!(this._canPlay || this._canPause))
    this._setFlag('can-play', !!canPlay)
    this._showNotification()
    this._sendDevelInfo()
  }
}

/**
 * Set whether it is possible to pause playback
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @param Boolean canPause    true if the "pause" button is active
 */
MediaPlayer.setCanPause = function (canPause) {
  if (this._canPause !== canPause) {
    this._canPause = canPause
    Nuvola.actions.setEnabled(PlayerAction.PAUSE, !!canPause)
    Nuvola.actions.setEnabled(PlayerAction.STOP, !!canPause)
    Nuvola.actions.setEnabled(PlayerAction.TOGGLE_PLAY, !!(this._canPlay || this._canPause))
    this._setFlag('can-pause', !!canPause)
    this._setFlag('can-stop', !!canPause)
    this._showNotification()
    this._sendDevelInfo()
  }
}

/**
 * Set whether it is possible to rate tracks
 *
 * If rating is enabled, signal @link{MediaPlayer::RatingSet} is emitted.
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @since API 3.1
 *
 * @param Boolean canRate    true if remote rating should be allowed
 */
MediaPlayer.setCanRate = function (canRate) {
  if (this._canRate !== canRate) {
    this._canRate = canRate
    this._setFlag('can-rate', !!canRate)
  }
}

/**
 * Set whether it is possible to seek to a specific position of the track
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @since API 4.5
 *
 * @param Boolean canSeek    true if remote seeking should be allowed
 */
MediaPlayer.setCanSeek = function (canSeek) {
  if (this._canSeek !== canSeek) {
    this._canSeek = canSeek
    Nuvola.actions.setEnabled(PlayerAction.SEEK, !!canSeek)
    this._setFlag('can-seek', !!canSeek)
  }
}

/**
 * Set whether it is possible to change volume
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @since API 4.5
 *
 * @param Boolean canChangeVolume    true if remote volume setting should be allowed
 */
MediaPlayer.setCanChangeVolume = function (canChangeVolume) {
  if (this._canChangeVolume !== canChangeVolume) {
    this._canChangeVolume = canChangeVolume
    Nuvola.actions.setEnabled(PlayerAction.CHANGE_VOLUME, !!canChangeVolume)
    this._setFlag('can-change-volume', !!canChangeVolume)
  }
}

/**
 * Set whether it is possible to shuffle playlist.
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @since Nuvola 4.13
 *
 * @param Boolean canShuffle    true if shuffle state should be allowed
 */
MediaPlayer.setCanShuffle = function (canShuffle) {
  Nuvola.actions.updateEnabledFlag(PlayerAction.SHUFFLE, canShuffle)
}

/**
 * Set the current shuffle state.
 *
 * If the argument is same as in the previous call, this method does nothing.
 *
 * @since Nuvola 4.13
 *
 * @param Boolean shuffle    true if the playback is in the shuffle mode
 */
MediaPlayer.setShuffleState = function (shuffle) {
  Nuvola.actions.updateState(PlayerAction.SHUFFLE, !!shuffle)
}

/**
 * Add actions for media player capabilities
 *
 * For example: star rating, thumbs up/down, like/love/unlike.
 *
 * Actions that have been already added are ignored.
 *
 * @param "Array of String" actions    names of actions
 */
MediaPlayer.addExtraActions = function (actions) {
  var update = false
  for (var i = 0; i < actions.length; i++) {
    var action = actions[i]
    if (!Nuvola.inArray(this._extraActions, action)) {
      this._extraActions.push(action)
      update = true
    }
  }

  if (update) {
    this._updateMenu()
    this._setActions()
  }
}

MediaPlayer._onInitAppRunner = function (emitter) {
  this._appRunner = true
  Nuvola.launcher.setActions(['quit'])
  Nuvola.actions.addAction('playback', 'win', PlayerAction.PLAY, 'Play', null, 'media-playback-start', null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.PAUSE, 'Pause', null, 'media-playback-pause', null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.TOGGLE_PLAY, 'Toggle play/pause', null, null, null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.STOP, 'Stop', null, 'media-playback-stop', null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.PREV_SONG, 'Previous song', null, 'media-skip-backward', null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.NEXT_SONG, 'Next song', null, 'media-skip-forward', null)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.SEEK, 'Seek', null, null, null, 0)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.CHANGE_VOLUME, 'Change volume', null, null, null, -1.0)
  Nuvola.actions.addAction('playback', 'win', PlayerAction.SHUFFLE, 'Shuffle tracks', null, null, null, false)
    // FIXME: remove action if notifications compoment is disabled
  Nuvola.actions.addAction('playback', 'win', PlayerAction.PLAYBACK_NOTIFICATION, 'Show playback notification', null, null, null)
  Nuvola.actions.addRadioAction('playback', 'win', PlayerAction.REPEAT, 0, repeatOptions)

  Nuvola.core.connect('ComponentLoaded', this)
  Nuvola.core.connect('ComponentUnloaded', this)
  Nuvola.core.isComponentLoadedAsync(COMPONENT_NOTIFICATIONS).then((loaded) => this._toggleNotifications(loaded))
  for (var i = 0; i < COMPONENTS_TO_ACTIVATE.length; i++) {
    this._activateComponent(COMPONENTS_TO_ACTIVATE[i])
  }
    // Take into account the old BACKGROUND_PLAYBACK value
  Nuvola.config.setDefaultAsync(BACKGROUND_PLAYBACK, true)
        .then(() => Nuvola.config.getAsync(BACKGROUND_PLAYBACK))
        .then((enabled) => {
          var defaultOption = RUN_IN_BACKGROUND_OPTIONS[enabled ? 1 : 2][0]
          return Nuvola.config.setDefaultAsync(RUN_IN_BACKGROUND, defaultOption)
        }).catch(console.log.bind(console))

  this._updateMenu()
  Nuvola.core.connect('PreferencesForm', this)
}

MediaPlayer._onInitWebWorker = function (emitter) {
  Nuvola.mediaKeys.connect('MediaKeyPressed', this)
  Nuvola.actions.connect('ActionActivated', this)
  Nuvola.core.connect('QuitRequest', this)
  this._track = {
    'title': undefined,
    'artist': undefined,
    'album': undefined,
    'artLocation': undefined,
    'rating': undefined
  }
  this.setPlaybackState(PlaybackState.UNKNOWN)
  this._setActions()

  Nuvola.core.connect('ComponentLoaded', this)
  Nuvola.core.connect('ComponentUnloaded', this)
  Nuvola.core.isComponentLoadedAsync(COMPONENT_NOTIFICATIONS).then((loaded) => this._toggleNotifications(loaded))

  Nuvola.config.connect('ConfigChanged', this)
  Nuvola.config.getAsync(RUN_IN_BACKGROUND)
        .then((value) => { this._runInBackground = value })
        .catch(console.log.bind(console))
}

MediaPlayer._onActionActivated = function (emitter, name, param) {
  switch (name) {
    case PlayerAction.PLAYBACK_NOTIFICATION:
      if (this._notification) { this._notification.show() }
      break
  }
}

MediaPlayer._setActions = function () {
  var actions = [
    this._state === PlaybackState.PLAYING ? PlayerAction.PAUSE : PlayerAction.PLAY,
    PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG, PlayerAction.SHUFFLE]
  actions = actions.concat(this._repeatActions).concat(this._extraActions)
  actions.push('quit')
  Nuvola.launcher.setActions(actions)
}

MediaPlayer._sendDevelInfo = function () {
  var rating = 1 * this._track.rating
  if (rating < 0 || isNaN(rating)) { rating = 0.0 } else if (rating > 1) { rating = 1 }

  var info = {
    'title': this._track.title || null,
    'artist': this._track.artist || null,
    'album': this._track.album || null,
    'rating': rating,
    'length': this._track.length || 0,
    'artworkLocation': this._track.artLocation || null,
    'artworkFile': this._artworkFile || null,
    'playbackActions': this._baseActions.concat(this._repeatActions).concat(this._extraActions),
    'state': ['unknown', 'paused', 'playing'][this._state]
  }
  Nuvola._callIpcMethodVoid('/nuvola/mediaplayer/set-track-info', info)
}

MediaPlayer._onArtworkDownloaded = function (res, changed) {
  if (!res.success) {
    this._artworkFile = null
    console.log(Nuvola.format('Artwork download failed: {1} {2}.', res.statusCode, res.statusText))
  } else {
    this._artworkFile = res.filePath
  }
  this._updateTrackInfo(changed)
}

MediaPlayer._updateTrackInfo = function (changed) {
  this._sendDevelInfo()
  var track = this._track

  if (track.title) {
    this._updateNotification()
    var tooltip = track.artist ? Nuvola.format('{1} by {2}', track.title, track.artist) : track.title
    Nuvola.launcher.setTooltip(tooltip)
  } else {
    Nuvola.launcher.setTooltip('Nuvola Player')
  }
}

MediaPlayer._updateNotification = function () {
  var track = this._track
  if (this._notification && track.title) {
    var title = track.title
    var message
    if (!track.artist && !track.album) { message = 'by unknown artist' } else if (!track.artist) { message = Nuvola.format('from {1}', track.album) } else if (!track.album) { message = Nuvola.format('by {1}', track.artist) } else { message = Nuvola.format('by {1} from {2}', track.artist, track.album) }

    this._notification.update(title, message, this._artworkFile ? null : 'nuvolaplayer', this._artworkFile)
    this._showNotification()
  }
}

MediaPlayer._showNotification = function () {
  if (this._notification) {
    Nuvola.notifications.isPersistenceSupportedAsync().then((supported) => {
      if (this._state === PlaybackState.PLAYING || supported) {
        this._notification.show()
      }
    })
  }
}

MediaPlayer._updateMenu = function () {
  Nuvola.menuBar.setMenu('playback', '_Control', this._baseActions.concat(this._extraActions))
}

MediaPlayer._onQuitRequest = function (emitter, result) {
  var option = this._runInBackground
  if (option === RUN_IN_BACKGROUND_OPTIONS[0][0] ||
    (option === RUN_IN_BACKGROUND_OPTIONS[1][0] && this._state === PlaybackState.PLAYING)) {
    result.approved = false
  }
}

MediaPlayer._onPreferencesForm = function (object, values, entries) {
    // TODO: @async
  values[RUN_IN_BACKGROUND] = Nuvola.config.get(RUN_IN_BACKGROUND)
  entries.push(['label', _('Run in background when window is closed')])
  for (var i = 0; i < RUN_IN_BACKGROUND_OPTIONS.length; i++) {
    var option = RUN_IN_BACKGROUND_OPTIONS[i]
    entries.push(['option', RUN_IN_BACKGROUND, option[0], option[1]])
  }
}

MediaPlayer._onMediaKeyPressed = function (emitter, key) {
  var A = Nuvola.actions
  switch (key) {
    case Nuvola.MediaKey.PLAY:
    case Nuvola.MediaKey.PAUSE:
      A.activate(PlayerAction.TOGGLE_PLAY)
      break
    case Nuvola.MediaKey.STOP:
      A.activate(PlayerAction.STOP)
      break
    case Nuvola.MediaKey.NEXT:
      A.activate(PlayerAction.NEXT_SONG)
      break
    case Nuvola.MediaKey.PREV:
      A.activate(PlayerAction.PREV_SONG)
      break
    default:
      console.log(Nuvola.format("Unknown media key '{1}'.", key))
      break
  }
}

MediaPlayer._onComponentLoaded = function (emitter, id) {
  if (id === COMPONENT_NOTIFICATIONS) { this._toggleNotifications(true) }

  if (Nuvola.inArray(COMPONENTS_TO_ACTIVATE, id)) { this._activateComponent(id) }
}

MediaPlayer._onComponentUnloaded = function (emitter, id) {
  if (id === COMPONENT_NOTIFICATIONS) { this._toggleNotifications(false) }
}

MediaPlayer._activateComponent = function (id) {
  Nuvola.core.toggleComponentActive(id, true)
}

MediaPlayer._toggleNotifications = function (enabled) {
  if (enabled) {
    this._notification = Nuvola.notifications.getNamedNotification('mediaplayer', true, 'x-gnome.music')
    if (this._appRunner) { this._notification.setActions([PlayerAction.PREV_SONG, PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.NEXT_SONG]) } else { this._updateNotification() }
  } else {
    this._notification = null
  }
}

MediaPlayer._onConfigChanged = function (emitter, key) {
  if (key === RUN_IN_BACKGROUND) {
    Nuvola.config.getAsync(RUN_IN_BACKGROUND)
        .then((value) => { this._runInBackground = value })
        .catch(console.log.bind(console))
  }
}

// export public items
Nuvola.PlayerAction = PlayerAction
Nuvola.PlaybackState = PlaybackState
Nuvola.PlayerRepeat = PlayerRepeat
Nuvola.MediaPlayer = MediaPlayer
