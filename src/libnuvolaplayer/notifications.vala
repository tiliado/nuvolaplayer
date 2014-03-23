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

namespace Nuvola.Extensions.Notifications
{

const string ACTIVE_WINDOW = "active_window";
const string RESIDENT = "resident";

public Nuvola.ExtensionInfo get_info()
{
	return
	{
		/// Name of a plugin providing integration with multimedia keys in GNOME
		_("Notifications"),
		Nuvola.get_version(),
		/// Description of a plugin providing integration with multimedia keys in GNOME
		_("<p>This plugin provides desktop notifications (<i>libnotify</i>).</p>"),
		"Jiří Janoušek",
		typeof(Extension),
		true
	};
}

/**
 * Manages notifications
 */
public class Extension : Nuvola.Extension
{
	private WebAppController controller;
	private Config config;
	private Gtk.Window main_window;
	private WebEngine web_engine;
	private Notify.Notification? notification = null;
	private bool actions_supported = false;
	private bool persistence_supported = false;
	private bool icons_supported = false;
	private uint queued_id = 0;
	
	public bool active_window
	{
		get
		{
			return config.get_bool(prefix + ACTIVE_WINDOW);
		}
		set
		{
			config.set_bool(prefix + ACTIVE_WINDOW, value);
		}
	}
	
	private bool _resident = false;
	public bool resident
	{
		get
		{
			return _resident;
		}
		set
		{
			_resident = value;
			config.set_bool(prefix + RESIDENT, value);
			force_show(); // apply change
		}
	}
	
	construct
	{
		has_preferences = true;
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(WebAppController controller) throws ExtensionError
	{
		this.controller = controller;
		this.config = controller.config;
		this.main_window = controller.main_window;
		this.web_engine = controller.web_engine;
		
		Notify.init(controller.app_name);
		unowned List<string> capabilities = Notify.get_server_caps();
		persistence_supported =  capabilities.find_custom("persistence", strcmp) != null;
		actions_supported =  capabilities.find_custom("actions", strcmp) != null;
		icons_supported =  capabilities.find_custom("action-icons", strcmp) != null;
		debug(@"Notifications: persistence $persistence_supported, actions $actions_supported, icons $icons_supported");
		config.defaults.insert(prefix + ACTIVE_WINDOW, new Variant.boolean(false));
		config.defaults.insert(prefix + RESIDENT, new Variant.boolean(true));
		_resident = config.get_bool(prefix + RESIDENT);
		web_engine.async_message_received.connect(on_async_message_received);
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		web_engine.async_message_received.disconnect(on_async_message_received);
		if (notification != null)
		{
			try
			{
				notification.close();
			}
			catch (GLib.Error e)
			{
			}
			notification = null;
		}
		Notify.uninit();
	}
	
	public void update(string title, string message, string? icon_name, string? icon_path)
	{
		if (notification == null)
		{
			notification = new Notify.Notification(title, message, icon_name ?? ""); 
		}
		else
		{
			notification.clear_hints();
			notification.clear_actions();
			notification.update(title, message, icon_name ?? "");
		}
		
		if (icon_path != null && icon_path != "")
		{
			try
			{
				// Pass actual image data over dbus instead of a filename to
				// prevent caching. LP:1099825
				notification.set_image_from_pixbuf(new Gdk.Pixbuf.from_file(icon_path));
			}
			catch(GLib.Error e)
			{
				warning("Failed to icon %s: %s", icon_path, e.message);
			}
		}
	}
	
	public void force_show()
	{
		if (queued_id == 0)
			queued_id = Idle.add(show_notification_cb);
	}
	
	public void show(bool ignore_paused=true)
	{
//~ 		if (!(resident && persistence_supported)
//~ 		&& player.playback_state != STATE_PLAYING
//~ 		&& ignore_paused || main_window.is_active && !active_window)
//~ 			return;
		
		force_show();
	}
	
	private bool show_notification_cb()
	{
		queued_id = 0;
		
		try
		{
			notification.show();
		}
		catch(Error e)
		{
			warning("Unable to show notification: %s", e.message);
		}
		
		return false;
	}
	
	private void on_async_message_received(WebEngine engine, string name, Variant? data)
	{
		if (name == "Nuvola.Notification.update")
		{
			string title = null;
			string message = null;
			string icon_name = null;
			string icon_path = null;
			if (data != null)
			{
				data.get("(ssss)", &title, &message, &icon_name, &icon_path);
				update(title, message, icon_name, icon_path);
			}
		}
		else if (name == "Nuvola.Notification.show")
		{
			show();
		}
	}
}

} // namespace Nuvola.Extensions.Notifications
