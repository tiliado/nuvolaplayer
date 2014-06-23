/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola.Extensions.MediaKeys
{

public Nuvola.ExtensionInfo get_info()
{
	return
	{
		/// Name of a plugin providing integration with multimedia keys in GNOME
		_("Media keys"),
		Nuvola.get_version(),
		/// Description of a plugin providing integration with multimedia keys in GNOME
		_("<p>This extension allows one to control playback with multimedia keys.</p>"),
		"Jiří Janoušek",
		typeof(Extension),
		true
	};
}

public const string X11_PLAY = "XF86AudioPlay";
//~ public const string X11_PLAY = "XF86Calculator";
public const string X11_PAUSE = "XF86AudioPause";
public const string X11_STOP = "XF86AudioStop";
public const string X11_PREV = "XF86AudioPrev";
public const string X11_NEXT = "XF86AudioNext";
//~ public const string X11_NEXT = "XF86Tools";
public const string GNOME_PLAY = "Play";
public const string GNOME_PAUSE = "Pause";
public const string GNOME_STOP = "Stop";
public const string GNOME_PREV = "Previous";
public const string GNOME_NEXT = "Next";

/**
 * Manages multimedia keys and pause key
 */
public class Extension: Nuvola.Extension
{
	private AppRunnerController controller;
	private WebEngine web_engine;
	private GlobalKeybinder keybinder;
	private GnomeMedia? media_keys;
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(AppRunnerController controller) throws ExtensionError
	{
		this.controller = controller;
		this.web_engine = controller.web_engine;
		this.keybinder = controller.keybinder;
		handle_multimedia_keys();
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		release_multimedia_keys();
		keybinder = null;
	}
	
	private void handle_multimedia_keys()
	{
		Bus.watch_name(BusType.SESSION, "org.gnome.SettingsDaemon",
		BusNameWatcherFlags.NONE, gnome_settings_appeared, gnome_settings_vanished);
	}
	
	private void release_multimedia_keys()
	{
		media_keys_stop_fallback();
		if (media_keys == null)
			return;
		
		try
		{
			media_keys.release_media_player_keys(controller.app_id);
			media_keys.media_player_key_pressed.disconnect(on_media_key_pressed);
			media_keys = null;
			
		}
		catch (IOError e)
		{
			warning("Unable to get proxy for GNOME Media keys: %s", e.message);
			media_keys = null;
		}
	}
	
	/**
	 * Use GNOME settings daemon to control multimedia keys
	 */
	private void gnome_settings_appeared(DBusConnection conn, string name, string owner)
	{
		debug("GNOME settings daemon appeared: %s, %s", name, owner);
		media_keys_stop_fallback();
		if (!try_gnome_keys())
		{
			media_keys = null;
			media_keys_fallback();
		}
	}
	
	private bool try_gnome_keys()
	{
		try
		{
			media_keys = Bus.get_proxy_sync(BusType.SESSION,
			"org.gnome.SettingsDaemon",
			"/org/gnome/SettingsDaemon/MediaKeys");
			/* Vala includes "return false" if DBus method call fails! */
			media_keys.grab_media_player_keys(controller.app_id, 0);
			media_keys.media_player_key_pressed.connect(on_media_key_pressed);
			return true;
			
		}
		catch (IOError e)
		{
			warning("Unable to get proxy for GNOME Media keys: %s", e.message);
			return false;
		}
	}
	
	private void gnome_settings_vanished(DBusConnection conn, string name)
	{
		debug("GNOME settings daemon vanished: %s", name);
		if (media_keys != null)
			media_keys.media_player_key_pressed.disconnect(on_media_key_pressed);
		media_keys = null;
		media_keys_fallback();
	}
	
	private void on_media_key_pressed(string app_name, string key)
	{
		debug("Media key pressed: %s, %s", app_name, key);
		if (app_name != controller.app_id)
			return;
		send_key_signal(key);
	}

	/**
	 * Fallback to use Xorg keybindings
	 */
	private void media_keys_fallback()
	{
		string[] keys = {X11_PLAY, X11_PAUSE, X11_STOP, X11_PREV, X11_NEXT};
		foreach (var key in keys)
			keybinder.bind(key, keybinder_handler);
	}
	
	private void media_keys_stop_fallback()
	{
		string[] keys = {X11_PLAY, X11_PAUSE, X11_STOP, X11_PREV, X11_NEXT};
		foreach (var key in keys)
			keybinder.unbind(key);
	}
	
	private void keybinder_handler(string key, Gdk.Event event)
	{
		switch (key)
		{
		case X11_PLAY:
			send_key_signal(GNOME_PLAY);
			break;
		case X11_PAUSE:
			send_key_signal(GNOME_PAUSE);
			break;
		case X11_STOP:
			send_key_signal(GNOME_STOP);
			break;
		case X11_PREV:
			send_key_signal(GNOME_PREV);
			break;
		case X11_NEXT:
			send_key_signal(GNOME_NEXT);
			break;
		default:
			warning("Unknown keybinding '%s'.", key);
			send_key_signal(key);
			break;
		}
	}
	
	private void send_key_signal(string key)
	{
		try
		{
			web_engine.call_function("Nuvola.MediaKeys.emit", new Variant("(ss)", "key-pressed", key));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
}


[DBus(name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMedia: Object
{
	public abstract void grab_media_player_keys(string app, uint32 time) throws IOError;
	public abstract void release_media_player_keys(string app) throws IOError;
	public signal void media_player_key_pressed(string app, string key);
}

} // namespace Nuvola.Extensions.MediaKeys
