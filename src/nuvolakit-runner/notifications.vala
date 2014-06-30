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


// https://people.gnome.org/~mccann/docs/notification-spec/notification-spec-latest.html

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

public class Notification
{
	public bool resident {get; private set; default = false;}
	private Notify.Notification notification = null;
	private string icon_path = "";
	private Diorite.Action[] actions = {};
	private bool shown_before = false;
	
	public Notification()
	{
	}
	
	public void update(string? summary, string? body, string? icon_name, string? icon_path, bool resident)
	{
		if (notification == null)
			notification = new Notify.Notification(summary ?? "", body ?? "", icon_name ?? "");
		else
			notification.update(summary ?? "", body ?? "", icon_name ?? "");
		
		this.icon_path = icon_path ?? "";
		this.resident = resident;
	}
	
	public void set_actions(Diorite.Action[] actions)
	{
		this.actions = actions;
	}
	
	public void show_once(bool add_actions)
	{
		if (!shown_before)
			show(add_actions);
	}
	
	public void show(bool add_actions)
	{
		return_if_fail(notification != null);
		notification.clear_hints();
		notification.clear_actions();
		
		if (icon_path != "")
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
		
		if (resident)
			notification.set_hint("resident", true);
		else
			notification.set_hint("transient", true);
		
		if (add_actions)
		{
			notification.set_hint("action-icons", true);
			
			foreach (var action in actions)
				if (action.enabled)
					notification.add_action(action.icon, action.label, () => { action.activate(null); });
		}
		
		try
		{
			notification.show();
			shown_before = true;
		}
		catch(Error e)
		{
			warning("Unable to show notification: %s", e.message);
		}
	}
}

/**
 * Manages notifications
 */
public class Extension : Nuvola.Extension
{
	private AppRunnerController controller;
	private Config config;
	private Gtk.Window main_window;
	private Diorite.ActionsRegistry actions_reg;
	
	private HashTable<string, Notification> notifications;
	private bool actions_supported = false;
	private bool persistence_supported = false;
	private bool icons_supported = false;
	
	construct
	{
		has_preferences = true;
		notifications = new HashTable<string, Notification>(str_hash, str_equal);
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(AppRunnerController controller) throws ExtensionError
	{
		this.controller = controller;
		this.config = controller.config;
		this.main_window = controller.main_window;
		this.actions_reg = controller.actions;
		
		Notify.init(controller.app_name);
		unowned List<string> capabilities = Notify.get_server_caps();
		persistence_supported =  capabilities.find_custom("persistence", strcmp) != null;
		actions_supported =  capabilities.find_custom("actions", strcmp) != null;
		icons_supported =  capabilities.find_custom("action-icons", strcmp) != null;
		debug(@"Notifications: persistence $persistence_supported, actions $actions_supported, icons $icons_supported");
		
		var action = controller.simple_action("view", "app", "show-notification", "Show notification", null, null, null, show_notifications);
		actions_reg.add_action(action);
		
		var server = controller.server;
		server.add_handler("Nuvola.Notification.update", handle_update);
		server.add_handler("Nuvola.Notification.setActions", handle_set_actions);
		server.add_handler("Nuvola.Notification.show", handle_show);
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		var server = controller.server;
		server.remove_handler("Nuvola.Notification.update");
		server.remove_handler("Nuvola.Notification.setActions");
		server.remove_handler("Nuvola.Notification.show");
		
		Notify.uninit();
	}
	
	public Notification get_or_create(string name)
	{
		var notification = notifications[name];
		if (notification == null)
		{
			notification = new Notification();
			notifications[name] = notification;
		}
		
		return notification;
	}
	
	public void update(string name, string summary, string body, string? icon_name, string? icon_path, bool resident)
	{
		get_or_create(name).update(summary, body, icon_name, icon_path, persistence_supported && resident);
	}
	
	public void set_actions(string name, string[] actions)
	{
		Diorite.Action[] actions_found = {};
		foreach (var action_name in actions)
		{
			var action = actions_reg.get_action(action_name);
			if (action != null)
				actions_found += action;
			else
				warning("Action '%s' not found.", action_name);
		}
		
		get_or_create(name).set_actions(actions_found);
	}
	
	public void show(string name, bool force)
	{
		var notification = get_or_create(name);
		var add_actions = actions_supported && icons_supported;
		
		if (force || !main_window.is_active)
			notification.show(add_actions);
		else if (notification.resident)
				notification.show_once(add_actions);
	}
	
	private void show_notifications()
	{
		foreach (var notification in notifications.get_values())
			notification.show(true);
	}
	
	private Variant? handle_update(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sssssb)");
		string name = null;
		string title = null;
		string message = null;
		string icon_name = null;
		string icon_path = null;
		bool resident = false;
		data.get("(sssssb)", &name, &title, &message, &icon_name, &icon_path);
		update(name, title, message, icon_name, icon_path, resident);
		return null;
	}
	
	private Variant? handle_set_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sav)");
		
		string name = null;
		int i = 0;
		VariantIter iter = null;
		data.get("(sav)", &name, &iter);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		set_actions(name, (owned) actions);
		return null;
	}
	
	private Variant? handle_show(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sb)");
		string name = null;
		bool force = false;
		data.get("(sb)", &name, &force);
		show(name, force);
		return null;
	}
}

} // namespace Nuvola.Extensions.Notifications
