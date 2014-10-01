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

public class Nuvola.ActionsBinding: Binding<ActionsInterface>
{
	public ActionsBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker)
	{
		base(server, web_worker, "Nuvola.Actions");
		bind("addAction", handle_add_action);
		bind("addRadioAction", handle_add_radio_action);
		bind("isEnabled", handle_is_action_enabled);
		bind("setEnabled", handle_action_set_enabled);
		bind("getState", handle_action_get_state);
		bind("setState", handle_action_set_state);
		bind("activate", handle_action_activate);
	}
	
	public override bool add(GLib.Object object)
	{
		var result = base.add(object);
		if (result)
			(object as ActionsInterface).custom_action_activated.connect(on_custom_action_activated);
		return result;
	}
	
	private Variant? handle_add_action(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(sssssss@*)");
		
		string group = null;
		string scope = null;
		string action_name = null;
		string? label = null;
		string? mnemo_label = null;
		string? icon = null;
		string? keybinding = null;
		Variant? state = null;
		
		data.get("(sssssss@*)", &group, &scope, &action_name, &label, &mnemo_label, &icon, &keybinding, &state);
		
		if (label == "")
			label = null;
		if (mnemo_label == "")
			mnemo_label = null;
		if (icon == "")
			icon = null;
		if (keybinding == "")
			keybinding = null;
		
		if (state != null && state.get_type_string() == "mv")
			state = null;
		
		foreach (var object in objects)
			if (object.add_action(group, scope, action_name, label, mnemo_label, icon, keybinding, state))
				break;
		
		return null;
	}
	
	private Variant? handle_add_radio_action(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(sss@*av)");
		
		string group = null;
		string scope = null;
		string action_name = null;
		string? label = null;
		string? mnemo_label = null;
		string? icon = null;
		string? keybinding = null;
		Variant? state = null;
		Variant? parameter = null;
		VariantIter? options_iter = null;
		
		data.get("(sss@*av)", &group, &scope, &action_name, &state, &options_iter);
		
		Diorite.RadioOption[] options = new Diorite.RadioOption[options_iter.n_children()];
		var i = 0;
		Variant? array = null;
		while (options_iter.next("v", &array))
		{
			Variant? value = array.get_child_value(0);
			parameter = value.get_variant();
			array.get_child(1, "v", &value);
			label = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
			array.get_child(2, "v", &value);
			mnemo_label = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
			array.get_child(3, "v", &value);
			icon = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
			array.get_child(4, "v", &value);
			keybinding = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
			options[i++] = new Diorite.RadioOption(parameter, label, mnemo_label, icon, keybinding);
		}
		
		foreach (var object in objects)
			if (object.add_radio_action(group, scope, action_name, state, options))
				break;
		
		return null;
	}
	
	private Variant? handle_is_action_enabled(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		
		string? action_name = null;
		data.get("(s)", &action_name);
		
		if (action_name == null)
			throw new Diorite.Ipc.MessageError.INVALID_ARGUMENTS("Action name must not be null");
		
		bool enabled = false;
		foreach (var object in objects)
			if (object.is_enabled(action_name, ref enabled))
				break;
		
		return new Variant.boolean(enabled);
	}
	
	private Variant? handle_action_set_enabled(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(sb)");
		string? action_name = null;
		bool enabled = false;
		data.get("(sb)", ref action_name, ref enabled);
		
		if (action_name == null)
			throw new Diorite.Ipc.MessageError.INVALID_ARGUMENTS("Action name must not be null");
		
		foreach (var object in objects)
			if (object.set_enabled(action_name, enabled))
				break;
		
		return null;
	}
	
	private Variant? handle_action_get_state(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string? action_name = null;
		data.get("(s)", &action_name);
		
		if (action_name == null)
			throw new Diorite.Ipc.MessageError.INVALID_ARGUMENTS("Action name must not be null");
		
		Variant? state = new Variant("mv", null);
		foreach (var object in objects)
			if (object.get_state(action_name, ref state))
				break;
		
		return state;
	}
	
	private Variant? handle_action_set_state(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(s@*)");
		string? action_name = null;
		Variant? state = null;
		data.get("(s@*)", &action_name, &state);
		
		if (action_name == null)
			throw new Diorite.Ipc.MessageError.INVALID_ARGUMENTS("Action name must not be null");
		
		foreach (var object in objects)
			if (object.set_state(action_name, state))
				break;
		
		return null;
	}
	
	private Variant? handle_action_activate(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(s@*)");
		
		string? action_name = null;
		Variant? parameter = null;
		data.get("(s@*)", &action_name, &parameter);
		
		if (action_name == null)
			throw new Diorite.Ipc.MessageError.INVALID_ARGUMENTS("Action name must not be null");
		
		bool handled = false;
		foreach (var object in objects)
			if (handled = object.activate(action_name, parameter))
				break;
		
		return new Variant.boolean(handled);
	}
	
	private void on_custom_action_activated(string name, Variant? parameter)
	{
		try
		{
			call_web_worker("Nuvola.actions.emit", new Variant("(ssmv)", "ActionActivated", name, parameter));
		}
		catch (GLib.Error e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
}
