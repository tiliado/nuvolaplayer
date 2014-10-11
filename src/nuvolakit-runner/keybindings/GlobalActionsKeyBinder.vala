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

public class GlobalActionsKeyBinder : GLib.Object, ActionsKeyBinder
{
	private XKeyGrabber grabber;
	private Config config;
	private Diorite.ActionsRegistry actions;
	private HashTable<string, string> keybindings;
	
	private static const string CONF_PREFIX = "nuvola.global_keybindings.";
	
	public class GlobalActionsKeyBinder(XKeyGrabber grabber, Config config, Diorite.ActionsRegistry actions)
	{
		this.grabber = grabber;
		this.config = config;
		this.actions = actions;
		keybindings = new HashTable<string, string>(str_hash, str_equal);
		grabber.keybinding_pressed.connect(on_keybinding_pressed);
	}
	
	public string? get_keybinding(string action)
	{
		return config.get_string(CONF_PREFIX + action);
	}
	
	public bool set_keybinding(string action, string? keybinding)
	{
		var old_keybinding = get_keybinding(action);
		if (old_keybinding != null)
		{
			grabber.ungrab(old_keybinding);
			warn_if_fail(keybindings[old_keybinding] == action);
			keybindings.remove(old_keybinding);
		}
		
		var result = keybinding == null || grabber.grab(keybinding, false);
		if (result)
		{
			if (keybinding != null)
				keybindings[keybinding] = action;
			config.set_string(CONF_PREFIX + action, keybinding);
		}
		return result;
	}
	
	public bool bind(string action)
	{
		var keybinding = get_keybinding(action);
		if (keybinding == null)
			return true;
		
		var bound_action = keybindings[keybinding];
		if (bound_action != null)
		{
			warning("Action %s has keybinding '%s' that is already bound to action %s.",
				action, keybinding, bound_action);
			return false;
		}
		
		if (grabber.grab(keybinding, false))
		{
			keybindings[keybinding] = action;
			return true;
		}
		
		warning("Failed to grab '%s' for %s.", keybinding, action);
		return false;
	}
	
	public bool unbind(string action)
	{
		var keybinding = get_keybinding(action);
		if (keybinding == null)
			return true;
		
		var bound_action = keybindings[keybinding];
		if (bound_action != action)
		{
			warning("Action %s has keybinding '%s' that is bound to action %s.",
				action, keybinding, bound_action);
			return false;
		}
		
		if (grabber.ungrab(keybinding))
		{
			keybindings.remove(keybinding);
			return true;
		}
		
		warning("Failed to ungrab '%s' for %s.", keybinding, action);
		return false;
	}
	
	public string? get_action(string keybinding)
	{
		return keybindings[keybinding];
	}
	
	public bool is_available(string keybinding)
	{
		return keybindings[keybinding] == null;
	}
	
	private void on_keybinding_pressed(string accelerator, uint32 time)
	{
		var name = keybindings[accelerator];
		if (name != null)
		{
			var action = actions.get_action(name);
			return_if_fail(action != null);
			action.activate(null);
		}
	}
}

} // namespace Nuvola
