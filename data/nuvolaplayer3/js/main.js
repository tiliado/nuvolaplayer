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

(function(Nuvola)
{

Nuvola.formatRegExp = new RegExp("{-?[0-9]+}", "g");
Nuvola.format = function ()
{
	var args = arguments;
	return args[0].replace(this.formatRegExp, function (item)
	{
		var index = parseInt(item.substring(1, item.length - 1));
		if (index > 0)
			return typeof args[index] !== 'undefined' ? args[index] : "";
		else if (index === -1)
			return "{";
		else if (index === -2)
			return "}";
		return "";
	});
};

Nuvola.inArray = function(array, item)
{
	return array.indexOf(item) > -1;
}

/**
* Triggers mouse event on element
* 
* @param elm Element object
* @param name Event name
*/
Nuvola.triggerMouseEvent = function(elm, name)
{
	var event = document.createEvent('MouseEvents');
	event.initMouseEvent(name, true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, elm);
	elm.dispatchEvent(event);
}

/**
* Simulates click on element
* 
* @param elm Element object
*/
Nuvola.clickOnElement = function(elm)
{
	Nuvola.triggerMouseEvent(elm, 'mouseover');
	Nuvola.triggerMouseEvent(elm, 'mousedown');
	Nuvola.triggerMouseEvent(elm, 'mouseup');
	Nuvola.triggerMouseEvent(elm, 'click');
}

/**
 * Creates HTML text node
 * @param text	text of the node
 * @return		new text node
 */
Nuvola.makeText = function(text)
{
	return document.createTextNode(text);
}

/**
 * Creates HTML element
 * @param name			element name
 * @param attributes	element attributes (optional)
 * @param text			text of the element (optional)
 * @return				new HTML element
 */
Nuvola.makeElement = function(name, attributes, text)
{
	var elm = document.createElement(name);
	attributes = attributes || {};
	for (var key in attributes)
		elm.setAttribute(key, attributes[key]);
	
	if (text !== undefined && text !== null)
		elm.appendChild(Nuvola.makeText(text));
	
	return elm;
}

Nuvola.makeSignaling = function(obj_proto)
{
	obj_proto.registerSignals = function(signals)
	{
		if (this.signals === undefined)
			this.signals = {};
		
		var size = signals.length;
		for (var i = 0; i < size; i++)
		{
			this.signals[signals[i]] = [];
		}
	}
	
	obj_proto.connect = function(name, object, handlerName)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		handlers.push([object, handlerName]);
	}
	
	obj_proto.disconnect = function(name, object, handlerName)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		var size = handlers.length;
		for (var i = 0; i < size; i++)
		{
			var handler = handlers[i];
			if (handler[0] === object && handler[1] === handlerName)
			{
				handlers.splice(i, 1);
				break;
			}
		}
	}
	
	obj_proto.emit = function(name)
	{
		var handlers = this.signals[name];
		if (handlers === undefined)
			throw new Error("Unknown signal '" + name + "'.");
		var size = handlers.length;
		var args = [this];
		for (var i = 1; i < arguments.length; i++)
			args.push(arguments[i]);
		
		for (var i = 0; i < size; i++)
		{
			var handler = handlers[i];
			var object = handler[0];
			object[handler[1]].apply(object, args);
		}
	}
}

Nuvola.makeSignaling(Nuvola);
Nuvola.registerSignals(["home-page", "navigation-request", "uri-changed", "last-page"]);

Nuvola.Notification =
{
	update: function(title, text, iconName, iconURL)
	{
		Nuvola._sendMessageAsync("Nuvola.Notification.update", title, text, iconName || "", iconURL || "");
	},
	
	show: function()
	{
		Nuvola._sendMessageAsync("Nuvola.Notification.show");
	},
}

Nuvola.TrayIcon =
{
	setTooltip: function(tooltip)
	{
		Nuvola._sendMessageAsync("Nuvola.TrayIcon.setTooltip", tooltip || "");
	},
	
	setActions: function(actions)
	{
		Nuvola._sendMessageAsync("Nuvola.TrayIcon.setActions", actions);
	},
}

Nuvola.Actions =
{
	buttons: {},
	
	addAction: function(group, scope, name, label, mnemo_label, icon, keybinding, state)
	{
		var state = state !== undefined ? state: null;
		Nuvola._sendMessageSync("Nuvola.Actions.addAction", group, scope, name, label || "", mnemo_label || "", icon || "", keybinding || "", state);
	},
	
	debug: function(arg1, arg2)
	{
		console.log(arg1 + ", " + arg2);
	},
	
	isEnabled: function(name)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.isEnabled", name);
	},
	
	setEnabled: function(name, enabled)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.setEnabled", name, enabled);
	},
	
	getState: function(name)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.getState", name);
	},
	
	setState: function(name, state)
	{
		return Nuvola._sendMessageSync("Nuvola.Actions.setState", name, state);
	},
	
	activate: function(name)
	{
		Nuvola._sendMessageAsync("Nuvola.Actions.activate", name);
	},
	
	attachButton: function(name, button)
	{
		this.buttons[name] = button;
		button.disabled = !Nuvola.Actions.isEnabled(name);
		button.setAttribute("data-action-name", name);
		button.addEventListener('click', function()
		{
			Nuvola.Actions.activate(this.getAttribute("data-action-name"));
		});
	},
	
	onEnabledChanged: function(object, name, enabled)
	{
		if (this.buttons[name])
			this.buttons[name].disabled = !enabled;
	}
}

Nuvola.makeSignaling(Nuvola.Actions);
Nuvola.Actions.registerSignals(["action-activated", "enabled-changed"]);
Nuvola.Actions.connect("action-activated", Nuvola.Actions, "debug");
Nuvola.Actions.connect("enabled-changed", Nuvola.Actions, "onEnabledChanged");

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
	
	state: 0,
	song: null,
	artist: null,
	album: null,
	artwork: null,
	prevSong: null,
	nextSong: null,
	prevData: {},
	extraActions: [],
	
	init: function()
	{
		Nuvola.TrayIcon.setActions(["quit"]);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PLAY, "Play", null, "media-playback-start", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PAUSE, "Pause", null, "media-playback-pause", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_TOGGLE_PLAY, "Toggle play/pause", null, null, null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_STOP, "Stop", null, "media-playback-stop", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_PREV_SONG, "Previous song", null, "media-skip-backward", null);
		Nuvola.Actions.addAction("playback", "win", this.ACTION_NEXT_SONG, "Next song", null, "media-skip-forward", null);
		this.updateMenu();
	},
	
	update: function()
	{
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
			
			Nuvola.Notification.update(title, message, "nuvolaplayer", null);
			Nuvola.Notification.show();
			
			if (this.artist)
				var tooltip = Nuvola.format("{1} by {2}", this.song, this.artist);
			else
				var tooltip = this.song;
			
			Nuvola.TrayIcon.setTooltip(tooltip);
		}
		else
		{
			Nuvola.TrayIcon.setTooltip("Nuvola Player");
		}
		
		
		var trayIconActions = [];
		if (this.state === this.STATE_PLAYING || this.state === this.STATE_PAUSED)
		{
			trayIconActions = [this.state === this.STATE_PAUSED ? this.ACTION_PLAY : this.ACTION_PAUSE, this.ACTION_PREV_SONG, this.ACTION_NEXT_SONG];
			trayIconActions = trayIconActions.concat(this.extraActions);
		}
		
		trayIconActions.push("quit");
		Nuvola.TrayIcon.setActions(trayIconActions);
		
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
		}
		
		if (Nuvola.inArray(changed, "prevSong"))
			Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_PREV_SONG, this.prevSong === true);
		
		if (Nuvola.inArray(changed, "nextSong"))
			Nuvola.Actions.setEnabled(Nuvola.Player.ACTION_NEXT_SONG, this.nextSong === true);
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
	}
};

Nuvola.Player.baseActions = [Nuvola.Player.ACTION_TOGGLE_PLAY, Nuvola.Player.ACTION_PLAY, Nuvola.Player.ACTION_PAUSE, Nuvola.Player.ACTION_PREV_SONG, Nuvola.Player.ACTION_NEXT_SONG],

Nuvola.Config = 
{
	hasKey: function(key)
	{
		return Nuvola._hasConfigKey(key);
	},
	get: function(key)
	{
		return Nuvola._getConfig(key);
	},
	set: function(key, value)
	{
		Nuvola._setConfig(key, value);
	}
};


Nuvola.MenuBar =
{
	setMenu: function(id, label, actions)
	{
		Nuvola._sendMessageAsync("Nuvola.MenuBar.setMenu", id, label, actions);
	},
}

Nuvola.Browser =
{
	ACTION_GO_BACK: "go-back",
	ACTION_GO_FORWARD: "go-forward",
	ACTION_GO_HOME: "go-home",
	ACTION_RELOAD: "reload"
}

})(this);  // function(Nuvola)
