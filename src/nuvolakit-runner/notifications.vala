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

namespace Nuvola
{

public class Notification
{
	public bool resident {get; private set; default = false;}
	private Notify.Notification notification = null;
	private string icon_path = "";
	private Diorite.Action[] actions = {};
	private bool shown_before = false;
	private string desktop_entry;
	private uint timeout_id = 0;
	
	public Notification(string desktop_entry)
	{
		this.desktop_entry = desktop_entry;
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
	
	public void remove_actions()
	{
		this.actions = {};
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
		
		notification.set_hint("desktop-entry", desktop_entry);
		
		if (add_actions)
		{
			notification.set_hint("action-icons", true);
			
			foreach (var action in actions)
				if (action.enabled)
					notification.add_action(action.icon, action.label, () => { action.activate(null); });
		}
		
		if (timeout_id != 0)
			Source.remove(timeout_id);
		timeout_id = Timeout.add(100, show_cb);
	}
	
	private bool show_cb()
	{
		timeout_id = 0;
		
		try
		{
			notification.show();
			shown_before = true;
		}
		catch(Error e)
		{
			warning("Unable to show notification: %s", e.message);
		}
		return false;
	}
}

/**
 * Manages notifications
 */
public class Notifications : GLib.Object, NotificationsInterface, NotificationInterface
{
	private AppRunnerController controller;
	private Config config;
	private Gtk.Window main_window;
	private Diorite.ActionsRegistry actions_reg;
	
	private HashTable<string, Notification> notifications;
	private bool actions_supported = false;
	private bool persistence_supported = false;
	private bool icons_supported = false;
	
	public Notifications(AppRunnerController controller)
	{
		this.controller = controller;
		this.config = controller.config;
		this.main_window = controller.main_window;
		this.actions_reg = controller.actions;
		
		notifications = new HashTable<string, Notification>(str_hash, str_equal);
		
		Notify.init(controller.app_name);
		unowned List<string> capabilities = Notify.get_server_caps();
		persistence_supported =  capabilities.find_custom("persistence", strcmp) != null;
		actions_supported =  capabilities.find_custom("actions", strcmp) != null;
		icons_supported =  capabilities.find_custom("action-icons", strcmp) != null;
		debug(@"Notifications: persistence $persistence_supported, actions $actions_supported, icons $icons_supported");
		
		var action = controller.actions_helper.simple_action("view", "app", "show-notification", "Show notification", null, null, null, show_notifications);
		actions_reg.add_action(action);
	}
	
	~Notifications()
	{

		Notify.uninit();
	}
	
	public Notification get_or_create(string name)
	{
		var notification = notifications[name];
		if (notification == null)
		{
			notification = new Notification(controller.app_id);
			notifications[name] = notification;
		}
		
		return notification;
	}
	
	public bool update(string name, string summary, string body, string? icon_name, string? icon_path, bool resident)
	{
		get_or_create(name).update(summary, body, icon_name, icon_path, persistence_supported && resident);
		return Binding.CONTINUE;
	}
	
	public bool set_actions(string name, string[] actions)
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
		return Binding.CONTINUE;
	}
	
	public bool remove_actions(string name)
	{
		get_or_create(name).remove_actions();
		return Binding.CONTINUE;
	}
	
	public bool show(string name, bool force)
	{
		var notification = get_or_create(name);
		var add_actions = actions_supported && icons_supported;
		
		if (force || !main_window.is_active)
			notification.show(add_actions);
		else if (notification.resident)
			notification.show_once(add_actions);
		return Binding.CONTINUE;
	}
	
	public bool show_anonymous(string summary, string body, string? icon_name, string? icon_path, bool force)
	{
		if (force || !main_window.is_active)
		{
			var notification = new Notification(controller.app_id);
			notification.update(summary, body, icon_name, icon_path, false);
			notification.show(false);
		}
		return Binding.CONTINUE;
	}
	
	private void show_notifications()
	{
		foreach (var notification in notifications.get_values())
			notification.show(true);
	}
}

} // namespace Nuvola.Extensions.Notifications
