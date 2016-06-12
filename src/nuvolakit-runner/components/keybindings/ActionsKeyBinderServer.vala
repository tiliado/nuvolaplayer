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

namespace Nuvola
{

public class ActionsKeyBinderServer : GLib.Object
{
	private Diorite.Ipc.MessageServer server;
	private ActionsKeyBinder keybinder;
	private unowned Queue<AppRunner> app_runners;
	
	public class ActionsKeyBinderServer(Diorite.Ipc.MessageServer server, ActionsKeyBinder keybinder, Queue<AppRunner> app_runners)
	{
		this.server = server;
		this.keybinder = keybinder;
		this.app_runners = app_runners;
		keybinder.action_activated.connect(on_action_activated);
		server.add_handler("ActionsKeyBinder.getKeybinding", "s", handle_get_keybinding);
		server.add_handler("ActionsKeyBinder.setKeybinding", "(sms)", handle_set_keybinding);
		server.add_handler("ActionsKeyBinder.bind", "s", handle_bind);
		server.add_handler("ActionsKeyBinder.unbind", "s", handle_unbind);
		server.add_handler("ActionsKeyBinder.isAvailable", "s", handle_is_available);
		server.add_handler("ActionsKeyBinder.getAction", "s", handle_get_action);
	}
	
	private Variant? handle_get_keybinding(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var action = data.get_string();
		return new Variant("ms", keybinder.get_keybinding(action));
	}
	
	private Variant? handle_set_keybinding(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		string? action = null;
		string? keybinding = null;
		data.get("(sms)", &action, &keybinding);
		return new Variant.boolean(keybinder.set_keybinding(action, keybinding));
	}
	
	private Variant? handle_bind(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var action = data.get_string();
		return new Variant.boolean(keybinder.bind(action));
	}
	
	private Variant? handle_unbind(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var action = data.get_string();
		return new Variant.boolean(keybinder.unbind(action));
	}
	
	private Variant? handle_get_action(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var keybinding = data.get_string();
		return new Variant("ms", keybinder.get_action(keybinding));
	}
	
	private Variant? handle_is_available(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var keybinding = data.get_string();
		return new Variant.boolean(keybinder.is_available(keybinding));
	}
	
	private void on_action_activated(string name)
	{
		unowned List<AppRunner> head = app_runners.head;
		var handled = false;
		foreach (var app_runner in head)
		{
			try
			{
				var response = app_runner.send_message("ActionsKeyBinder.actionActivated", new Variant.string(name));
				if (!Diorite.variant_bool(response, ref handled))
				{
					warning("Got invalid response from %s instance %s: %s\n", Nuvola.get_app_name(), app_runner.app_id,
						response == null ? "null" : response.print(true));
				}
				else if(handled)
				{
					debug("Action %s was handled in %s.", name, app_runner.app_id);
					break;
				}
			}
			catch (GLib.Error e)
			{
				warning("Communication with app runner %s for action %s failed. %s", app_runner.app_id, name, e.message);
			}
		}
		
		if (!handled)
			warning("Action %s was not handled by any app runner.", name);
	}
}

} // namespace Nuvola
