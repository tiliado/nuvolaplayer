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

require("notification");
require("launcher");
require("actions");
require("mediakeys");
require("storage");
require("browser");


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

Nuvola.Player = 
{
	BACKGROUND_PLAYBACK: "player.background_playback",
	state: 0,
	song: null,
	artist: null,
	album: null,
	artwork: null,
	artworkFile: null,
	prevSong: null,
	nextSong: null,
	prevData: {},
	extraActions: [],
	firstUpdate: true,
	_artworkLoop: 0,
	
	init: function()
	{
		Nuvola.Launcher.setActions(["quit"]);
		Nuvola.Notification.setActions([PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG]);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.PLAY, "Play", null, "media-playback-start", null);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.PAUSE, "Pause", null, "media-playback-pause", null);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.TOGGLE_PLAY, "Toggle play/pause", null, null, null);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.STOP, "Stop", null, "media-playback-stop", null);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.PREV_SONG, "Previous song", null, "media-skip-backward", null);
		Nuvola.Actions.addAction("playback", "win", PlayerAction.NEXT_SONG, "Next song", null, "media-skip-forward", null);
		Nuvola.Config.setDefault(this.BACKGROUND_PLAYBACK, true);
		this.updateMenu();
		Nuvola.Core.connect("append-preferences", this, "onAppendPreferences");
	},
	
	beforeFirstUpdate: function()
	{
		Nuvola.Config.connect("config-changed", this, "onConfigChanged");
		Nuvola.MediaKeys.connect("key-pressed", this, "onMediaKeyPressed");
	},
	
	update: function()
	{
		if (this.firstUpdate)
		{
			this.beforeFirstUpdate();
			this.firstUpdate = false;
		}
		
		var changed = [];
		var keys = ["song", "artist", "album", "artwork", "state", "prevSong", "nextSong"];
		for (var i = 0; i < keys.length; i++)
		{
			var key = keys[i];
			if (this.prevData[key] !== this[key])
			{
				this.prevData[key] = this[key];
				changed.push(key);
			}
		}
		
		if (!changed.length)
			return;
		
		var trayIconActions = [];
		if (this.state === PlaybackState.PLAYING || this.state === PlaybackState.PAUSED)
		{
			trayIconActions = [this.state === this.STATE_PAUSED ? PlayerAction.PLAY : PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG];
			trayIconActions = trayIconActions.concat(this.extraActions);
		}
		
		trayIconActions.push("quit");
		Nuvola.Launcher.setActions(trayIconActions);
		
		
		if (Nuvola.inArray(changed, "state"))
		{
			switch (this.state)
			{
			case PlaybackState.PLAYING:
				Nuvola.Actions.setEnabled(PlayerAction.TOGGLE_PLAY, true);
				Nuvola.Actions.setEnabled(PlayerAction.PLAY, false);
				Nuvola.Actions.setEnabled(PlayerAction.PAUSE, true);
				break;
			case PlaybackState.PAUSED:
				Nuvola.Actions.setEnabled(PlayerAction.TOGGLE_PLAY, true);
				Nuvola.Actions.setEnabled(PlayerAction.PLAY, true);
				Nuvola.Actions.setEnabled(PlayerAction.PAUSE, false);
				break;
			default:
				Nuvola.Actions.setEnabled(PlayerAction.TOGGLE_PLAY, false);
				Nuvola.Actions.setEnabled(PlayerAction.PLAY, false);
				Nuvola.Actions.setEnabled(PlayerAction.PAUSE, false);
				break;
			}
			this.setHideOnClose();
		}
		
		if (Nuvola.inArray(changed, "prevSong"))
			Nuvola.Actions.setEnabled(PlayerAction.PREV_SONG, this.prevSong === true);
		
		if (Nuvola.inArray(changed, "nextSong"))
			Nuvola.Actions.setEnabled(PlayerAction.NEXT_SONG, this.nextSong === true);
		
		if (!this.artwork)
			this.artworkFile = null;
		
		if (Nuvola.inArray(changed, "artwork") && this.artwork)
		{
			this.artworkFile = null;
			var artworkId = this._artworkLoop++;
			if (this._artworkLoop > 9)
				this._artworkLoop = 0;
			Nuvola.Browser.downloadFileAsync(this.artwork, "player.artwork." + artworkId, this.onArtworkDownloaded.bind(this), changed);
			this.sendDevelInfo();
		}
		else
		{
			this.updateTrackInfo(changed);
		}
	},
	
	sendDevelInfo: function()
	{
		var data = {};
		var keys = ["song", "artist", "album", "artwork", "artworkFile", "baseActions", "extraActions"];
		for (var i = 0; i < keys.length; i++)
		{
			var key = keys[i];
			data[key] = this[key];
		}
		
		data.state = ["unknown", "paused", "playing"][this.state];
		Nuvola._sendMessageAsync("Nuvola.Player.sendDevelInfo", data);
	},
	
	onArtworkDownloaded: function(res, changed)
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
	},
	
	updateTrackInfo: function(changed)
	{
		this.sendDevelInfo();
		if (this.song)
		{
			var title = this.song;
			var message;
			if (!this.artist && !this.album)
				message = "by unknown artist";
			else if(!this.artist)
				message = Nuvola.format("from {1}", this.album);
			else if(!this.album)
				message = Nuvola.format("by {1}", this.artist);
			else
				message = Nuvola.format("by {1} from {2}", this.artist, this.album);
			
			Nuvola.Notification.update(title, message, this.artworkFile ? null : "nuvolaplayer", this.artworkFile);
			if (this.state === PlaybackState.PLAYING)
				Nuvola.Notification.show();
			
			if (this.artist)
				var tooltip = Nuvola.format("{1} by {2}", this.song, this.artist);
			else
				var tooltip = this.song;
			
			Nuvola.Launcher.setTooltip(tooltip);
		}
		else
		{
			Nuvola.Launcher.setTooltip("Nuvola Player");
		}
	},
	
	addExtraActions: function(actions)
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
	},
	
	updateMenu: function()
	{
		Nuvola.MenuBar.setMenu("playback", "_Control", this.baseActions.concat(this.extraActions));
	},
	
	setHideOnClose: function()
	{
		if (this.state === PlaybackState.PLAYING)
			Nuvola.Core.setHideOnClose(Nuvola.Config.get(this.BACKGROUND_PLAYBACK));
		else
			Nuvola.Core.setHideOnClose(false);
	},
	
	onAppendPreferences: function(object, values, entries)
	{
		values[this.BACKGROUND_PLAYBACK] = Nuvola.Config.get(this.BACKGROUND_PLAYBACK);
		entries.push(["bool", this.BACKGROUND_PLAYBACK, "Keep playing in background when window is closed"]);
	},
	
	onConfigChanged: function(emitter, key)
	{
		switch (key)
		{
		case this.BACKGROUND_PLAYBACK:
			this.setHideOnClose();
			break;
		}
	},
	
	onMediaKeyPressed: function(emitter, key)
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
};

Nuvola.Player.baseActions = [PlayerAction.TOGGLE_PLAY, PlayerAction.PLAY, PlayerAction.PAUSE, PlayerAction.PREV_SONG, PlayerAction.NEXT_SONG],
Nuvola.PlayerAction = PlayerAction;
Nuvola.PlaybackState = PlaybackState;
