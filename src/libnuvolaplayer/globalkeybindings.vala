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

public class GlobalKeybindings : GLib.Object
{
	private GlobalKeybinder keybinder;
	private Config config;
	private Diorite.ActionsRegistry actions;
	private HashTable<string, string> keybindings;
	private static const string CONF_PREFIX = "nuvola.global_keybindings.";
	
	public class GlobalKeybindings(GlobalKeybinder keybinder, Config config, Diorite.ActionsRegistry actions)
	{
		this.keybinder = keybinder;
		this.config = config;
		this.actions = actions;
		keybindings = new HashTable<string, string>(str_hash, str_equal);
		foreach (var action in actions.list_actions())
		{
			if (action is Diorite.RadioAction)
				continue;
			
			var name = action.name;
			var keybinding = get_keybinding(name);
			if (keybinding == null || keybinding == "")
				continue;
			
			bind(name, keybinding);
		}
		actions.action_added.connect(on_action_added);
	}
	
	public string? get_keybinding(string action_name)
	{
		return config.get_string(CONF_PREFIX + action_name);
	}
	
	public bool set_keybinding(string action_name, string? keybinding)
	{
		var old_keybinding = get_keybinding(action_name);
		if (old_keybinding != null)
			unbind(action_name, old_keybinding);
		
		
		var result = keybinding == null || bind(action_name, keybinding);
		if (result)
			config.set_string(CONF_PREFIX + action_name, keybinding);
		return result;
	}
	
	private bool bind(string name, string keybinding)
	{
		if (!keybinder.bind(keybinding, keybinder_handler))
		{
			warning("Failed to bind %s to %s.", name, keybinding);
			return false;
		}
		
		debug("Bound %s to %s.", name, keybinding);
		keybindings.insert(keybinding, name);
		return true;
	}
	
	private void unbind(string name, string keybinding)
	{
		if (!keybinder.unbind(keybinding))
			warning("Failed to unbind %s from %s.", name, keybinding);
		keybindings.remove(keybinding);
	}
	
	private void keybinder_handler(string accelerator, Gdk.Event event)
	{
		var name = keybindings.lookup(accelerator);
		var action = actions.get_action(name);
		return_if_fail(action != null);
		action.activate(null);
	}
	
	private void on_action_added(Diorite.Action action)
	{
		var name = action.name;
		var keybinding = get_keybinding(name);
		if (keybinding != null && keybinding != "")
			bind(name, keybinding);
	}
}

} // namespace Nuvola
