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

public class Nuvola.ActionsHelper: GLib.Object, ActionsInterface
{
	private Diorite.ActionsRegistry actions;
	private Config config;
	
	public ActionsHelper(Diorite.ActionsRegistry actions, Config config)
	{
		this.actions = actions;
		this.config = config;
	}
	
	public void activate(string action_name)
	{
		var action = actions.get_action(action_name);
		if (action != null)
			action.activate(null);
	}
	
	public void set_state(string action_name, Variant? state)
	{
		var action = actions.get_action(action_name);
		if (action != null)
			action.state = state;
	}
	
	public void get_state(string action_name, ref Variant? state)
	{
		var action = actions.get_action(action_name);
		if (action != null)
			state = action.state;
	}
	
	public void is_enabled(string action_name, ref bool enabled)
	{
		var action = actions.get_action(action_name);
		if (action != null)
			enabled = action.enabled;
	}
	
	public void set_enabled(string action_name, bool enabled)
	{
		var action = actions.get_action(action_name);
		if (action != null && action.enabled != enabled)
			action.enabled = enabled;
	}
	
	public void add_action(string group, string scope, string action_name, string? label, string? mnemo_label, string? icon, string? keybinding, Variant? state)
	{
		Diorite.Action action;
		if (state == null)
			action = simple_action(group, scope, action_name, label, mnemo_label, icon, keybinding, null);
		else
			action = toggle_action(group, scope, action_name, label, mnemo_label, icon, keybinding, null, state);
		
		action.enabled = false;
		action.activated.connect(on_custom_action_activated);
		actions.add_action(action);
	}
	
	public void add_radio_action(string group, string scope, string name, Variant state, Diorite.RadioOption[] options)
	{
		var radio = new Diorite.RadioAction(group, scope, name, null, state, options);
		radio.enabled = false;
		radio.activated.connect(on_custom_action_activated);
		actions.add_action(radio);
	}
	
	public Diorite.SimpleAction simple_action(string group, string scope, string name, string? label, string? mnemo_label, string? icon, string? keybinding, owned Diorite.ActionCallback? callback)
	{
		var kbd = config.get_string("nuvola.keybindings." + name) ?? keybinding;
		if (kbd == "")
			kbd = null;
		return new Diorite.SimpleAction(group, scope, name, label, mnemo_label, icon, kbd, (owned) callback);
	}
	
	public Diorite.ToggleAction toggle_action(string group, string scope, string name, string? label, string? mnemo_label, string? icon, string? keybinding, owned Diorite.ActionCallback? callback, Variant state)
	{
		var kbd = config.get_string("nuvola.keybindings." + name) ?? keybinding;
		return new Diorite.ToggleAction(group, scope, name, label, mnemo_label, icon, kbd, (owned) callback, state);
	}
	
	private void on_custom_action_activated(Diorite.Action action, Variant? parameter)
	{
		custom_action_activated(action.name, parameter);
	}
}
