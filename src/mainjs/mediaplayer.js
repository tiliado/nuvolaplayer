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

Nuvola.Player = 
{
	ACTION_PLAY: "play",
	ACTION_TOGGLE_PLAY: "toggle-play",
	ACTION_PAUSE: "pause",
	ACTION_STOP: "stop",
	ACTION_PREV_SONG: "prev-song",
	ACTION_NEXT_SONG: "next-song",
	STATE_UNKNOWN: 0,
	STATE_PAUSED: 1,
	STATE_PLAYING: 2,
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
		Nuvola.Notification.setActions([this.ACTION_PLAY, this.ACTION_PAUSE, this.ACTION_PREV_SONG, this.ACTION_NEXT_SONG]);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PLAY, "Play", null, "media-playback-start", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PAUSE, "Pause", null, "media-playback-pause", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_TOGGLE_PLAY, "Toggle play/pause", null, null, null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_STOP, "Stop", null, "media-playback-stop", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PREV_SONG, "Previous song", null, "media-skip-backward", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_NEXT_SONG, "Next song", null, "media-skip-forward", null);
		Nuvola.Config.setDefault(this.BACKGROUND_PLAYBACK, true);
		this.updateMenu();
		Nuvola.connect("append-preferences", this, "onAppendPreferences");
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
		if (this.state === this.STATE_PLAYING || this.state === this.STATE_PAUSED)
		{
			trayIconActions = [this.state === this.STATE_PAUSED ? this.ACTION_PLAY : this.ACTION_PAUSE, this.ACTION_PREV_SONG, this.ACTION_NEXT_SONG];
			trayIconActions = trayIconActions.concat(this.extraActions);
		}
		
		Nuvola.UnityDockItem.setActions(trayIconActions);
		trayIconActions.push("quit");
		Nuvola.Launcher.setActions(trayIconActions);
		
		
		if (Nuvola.inArray(changed, "state"))
		{
			switch (this.state)
			{
			case this.STATE_PLAYING:
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_TOGGLE_PLAY, true);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PLAY, false);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PAUSE, true);
				break;
			case this.STATE_PAUSED:
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_TOGGLE_PLAY, true);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PLAY, true);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PAUSE, false);
				break;
			default:
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_TOGGLE_PLAY, false);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PLAY, false);
				Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PAUSE, false);
				break;
			}
			this.setHideOnClose();
		}
		
		if (Nuvola.inArray(changed, "prevSong"))
			Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PREV_SONG, this.prevSong === true);
		
		if (Nuvola.inArray(changed, "nextSong"))
			Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_NEXT_SONG, this.nextSong === true);
		
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
			if (this.state === this.STATE_PLAYING)
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
		if (this.state === this.STATE_PLAYING)
			Nuvola.setHideOnClose(Nuvola.Config.get(this.BACKGROUND_PLAYBACK));
		else
			Nuvola.setHideOnClose(false);
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
		var K = Nuvola.MediaKeys;
		var A = Nuvola.Actions;
		switch (key)
		{
		case K.PLAY:
		case K.PAUSE:
			A.activate(this.ACTION_TOGGLE_PLAY);
			break;
		case K.STOP:
			A.activate(this.ACTION_STOP);
			break;
		case K.NEXT:
			A.activate(this.ACTION_NEXT_SONG);
			break;
		case K.PREV:
			A.activate(this.ACTION_PREV_SONG);
			break;
		default:
			console.log(Nuvola.format("Unknown media key '{1}'.", key));
			break;
		}
	}
};

Nuvola.Player.baseActions = [Nuvola.Player.ACTION_TOGGLE_PLAY, Nuvola.Player.ACTION_PLAY, Nuvola.Player.ACTION_PAUSE, Nuvola.Player.ACTION_PREV_SONG, Nuvola.Player.ACTION_NEXT_SONG],
