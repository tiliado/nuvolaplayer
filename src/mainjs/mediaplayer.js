/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

require("prototype");
require("notification");
require("launcher");
require("actions");
require("mediakeys");
require("storage");
require("browser");
require("core");


var PlayerAction = {
	PLAY: "play",
	TOGGLE_PLAY: "toggle-play",
	PAUSE: "pause",
	STOP: "stop",
	PREV_SONG: "prev-song",
	NEXT_SONG: "next-song",
}

var PlaybackState = {
	UNKNOWN: 0,
	PAUSED: 1,
	PLAYING: 2,
}

var MediaPlayer = $prototype(null);

MediaPlayer.$init = function()
{
	this.state = PlaybackState.UNKNOWN;
	this.artworkFile = null;
	this.canGoPrev = null;
	this.canGoNext = null;
	this.canPlay = null;
	this.canPause = null;
	this.extraActions = [];
	this._artworkLoop = 0;
	this.baseActions = [PlayerAction.TOGGLE_PLAY, PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG];
	this.notification = Nuvola.Notifications.getNamedNotification("mediaplayer", true);
	Nuvola.Core.connect("init-app-runner", this, "onInitAppRunner");
	Nuvola.Core.connect("init-web-worker", this, "onInitWebWorker");
}

MediaPlayer.BACKGROUND_PLAYBACK = "player.background_playback";

MediaPlayer.onInitAppRunner = function(emitter, values, entries)
{
	Nuvola.Launcher.setActions(["quit"]);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.PLAY, "Play", null, "media-playback-start", null);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.PAUSE, "Pause", null, "media-playback-pause", null);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.TOGGLE_PLAY, "Toggle play/pause", null, null, null);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.STOP, "Stop", null, "media-playback-stop", null);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.PREV_SONG, "Previous song", null, "media-skip-backward", null);
	Nuvola.Actions.addAction("playback", "win", PlayerAction.NEXT_SONG, "Next song", null, "media-skip-forward", null);
	this.notification.setActions([PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG]);
	Nuvola.Config.setDefault(this.BACKGROUND_PLAYBACK, true);
	this.updateMenu();
	Nuvola.Core.connect("append-preferences", this, "onAppendPreferences");
}

MediaPlayer.onInitWebWorker = function(emitter)
{
	Nuvola.Config.connect("config-changed", this, "onConfigChanged");
	Nuvola.MediaKeys.connect("key-pressed", this, "onMediaKeyPressed");
	this.track = {
		"title": undefined,
		"artist": undefined,
		"album": undefined,
		"artLocation": undefined
	};
	this._setActions();
}

MediaPlayer.setTrack = function(track)
{
	var changed = Nuvola.objectDiff(this.track, track);
	this.track = track;
	
	if (!changed.length)
		return;
		
	if (!track.artLocation)
		this.artworkFile = null;
	
	if (Nuvola.inArray(changed, "artLocation") && track.artLocation)
	{
		this.artworkFile = null;
		var artworkId = this._artworkLoop++;
		if (this._artworkLoop > 9)
			this._artworkLoop = 0;
		Nuvola.Browser.downloadFileAsync(track.artLocation, "player.artwork." + artworkId, this.onArtworkDownloaded.bind(this), changed);
		this.sendDevelInfo();
	}
	else
	{
		this.updateTrackInfo(changed);
	}
}

MediaPlayer.setPlaybackState = function(state)
{
	if (this.state !== state)
	{
		this.state = state;
		this.setHideOnClose();
		this._setActions();
		this.updateTrackInfo(["state"]);
	}
}

MediaPlayer.setCanGoNext = function(canGoNext)
{
	if (this.canGoNext !== canGoNext)
	{
		this.canGoNext = canGoNext;
		Nuvola.Actions.setEnabled(PlayerAction.NEXT_SONG, !!canGoNext);
		this.sendDevelInfo();
	}
}

MediaPlayer.setCanGoPrev = function(canGoPrev)
{
	if (this.canGoPrev !== canGoPrev)
	{
		this.canGoPrev = canGoPrev;
		Nuvola.Actions.setEnabled(PlayerAction.PREV_SONG, !!canGoPrev);
		this.sendDevelInfo();
	}
}

MediaPlayer.setCanPlay = function(canPlay)
{
	if (this.canPlay !== canPlay)
	{
		this.canPlay = canPlay;
		Nuvola.Actions.setEnabled(PlayerAction.PLAY, !!canPlay);
		Nuvola.Actions.setEnabled(PlayerAction.TOGGLE_PLAY, !!(this.canPlay || this.canPause));
		this.sendDevelInfo();
	}
}

MediaPlayer.setCanPause = function(canPause)
{
	if (this.canPause !== canPause)
	{
		this.canPause = canPause;
		Nuvola.Actions.setEnabled(PlayerAction.PAUSE, !!canPause);
		Nuvola.Actions.setEnabled(PlayerAction.TOGGLE_PLAY, !!(this.canPlay || this.canPause));
		this.sendDevelInfo();
	}
}

MediaPlayer._setActions = function()
{
	var actions = [this.state === PlaybackState.PLAYING ? PlayerAction.PAUSE : PlayerAction.PLAY, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG];
	actions = actions.concat(this.extraActions);
	actions.push("quit");
	Nuvola.Launcher.setActions(actions);
}

MediaPlayer.sendDevelInfo = function()
{
	var data = {};
	var keys = ["title", "artist", "album", "artLocation", "artworkFile", "baseActions", "extraActions"];
	for (var i = 0; i < keys.length; i++)
	{
		var key = keys[i];
		if (this.track.hasOwnProperty(key))
			data[key] = this.track[key];
		else
			data[key] = this[key];
	}
	
	data.state = ["unknown", "paused", "playing"][this.state];
	Nuvola._sendMessageAsync("Nuvola.MediaPlayer.sendDevelInfo", data);
}

MediaPlayer.onArtworkDownloaded = function(res, changed)
{
	if (!res.result)
	{
		this.artworkFile = null;
		console.log(Nuvola.format("Artwork download failed: {1} {2}.", res.statusCode, res.statusText));
	}
	else
	{
		this.artworkFile = res.filePath;
	}
	this.updateTrackInfo(changed);
}

MediaPlayer.updateTrackInfo = function(changed)
{
	this.sendDevelInfo();
	var track = this.track;
	
	if (track.title)
	{
		var title = track.title;
		var message;
		if (!track.artist && !track.album)
			message = "by unknown artist";
		else if(!track.artist)
			message = Nuvola.format("from {1}", track.album);
		else if(!track.album)
			message = Nuvola.format("by {1}", track.artist);
		else
			message = Nuvola.format("by {1} from {2}", track.artist, track.album);
		
		this.notification.update(title, message, this.artworkFile ? null : "nuvolaplayer", this.artworkFile);
		if (this.state === PlaybackState.PLAYING)
			this.notification.show();
		
		var tooltip = track.artist ? Nuvola.format("{1} by {2}", track.title, track.artist) : track.title;
		Nuvola.Launcher.setTooltip(tooltip);
	}
	else
	{
		Nuvola.Launcher.setTooltip("Nuvola Player");
	}
}

MediaPlayer.addExtraActions = function(actions)
{
	var update = false;
	for (var i = 0; i < actions.length; i++)
	{
		var action = actions[i];
		if (!Nuvola.inArray(this.extraActions, action))
		{
			this.extraActions.push(action);
			update = true;
		}
	}
	if (update)
		this.updateMenu();
}

MediaPlayer.updateMenu = function()
{
	Nuvola.MenuBar.setMenu("playback", "_Control", this.baseActions.concat(this.extraActions));
}

MediaPlayer.setHideOnClose = function()
{
	if (this.state === PlaybackState.PLAYING)
		Nuvola.Core.setHideOnClose(Nuvola.Config.get(this.BACKGROUND_PLAYBACK));
	else
		Nuvola.Core.setHideOnClose(false);
}

MediaPlayer.onAppendPreferences = function(object, values, entries)
{
	values[this.BACKGROUND_PLAYBACK] = Nuvola.Config.get(this.BACKGROUND_PLAYBACK);
	entries.push(["bool", this.BACKGROUND_PLAYBACK, "Keep playing in background when window is closed"]);
}

MediaPlayer.onConfigChanged = function(emitter, key)
{
	switch (key)
	{
	case this.BACKGROUND_PLAYBACK:
		this.setHideOnClose();
		break;
	}
}

MediaPlayer.onMediaKeyPressed = function(emitter, key)
{
	var A = Nuvola.Actions;
	switch (key)
	{
	case MediaKey.PLAY:
	case MediaKey.PAUSE:
		A.activate(PlayerAction.TOGGLE_PLAY);
		break;
	case MediaKey.STOP:
		A.activate(PlayerAction.STOP);
		break;
	case MediaKey.NEXT:
		A.activate(PlayerAction.NEXT_SONG);
		break;
	case MediaKey.PREV:
		A.activate(PlayerAction.PREV_SONG);
		break;
	default:
		console.log(Nuvola.format("Unknown media key '{1}'.", key));
		break;
	}
}

// export public items
Nuvola.PlayerAction = PlayerAction;
Nuvola.PlaybackState = PlaybackState;
Nuvola.MediaPlayer = MediaPlayer;
