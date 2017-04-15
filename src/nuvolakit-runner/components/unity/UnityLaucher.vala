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

#if UNITY
namespace Nuvola
{

/**
 * Manages dock item at Unity Launcher
 */
public class UnityLauncher: GLib.Object
{
	private Diorite.Application controller;
	private Diorite.Actions actions_reg;
	private Unity.LauncherEntry dock_item;
	private LauncherModel model;
	private SList<ActionAdaptor> adaptors = null;
	
	public UnityLauncher(Diorite.Application controller, LauncherModel model)
	{
		this.controller = controller;
		this.actions_reg = controller.actions;
		this.model = model;
		this.dock_item = Unity.LauncherEntry.get_for_desktop_id(controller.desktop_name);
		this.dock_item.quicklist = new Dbusmenu.Menuitem();
		model.notify.connect_after(on_model_changed);
	}
	
	~UnityLauncher()
	{
		remove_menu();
	}
	
	private void on_model_changed(GLib.Object o, ParamSpec p)
	{
		switch (p.name)
		{
		case "actions":
			update_menu();
			break;
		}
	}
	
	private void clear_menu()
	{
		if (dock_item == null || this.dock_item.quicklist == null)
			return;
		
		var menu = dock_item.quicklist;
		adaptors = null;
		menu.take_children();
	}
	
	private void update_menu()
	{
		clear_menu();
		var menu = dock_item.quicklist;
		foreach (var action_name in model.actions)
		{
			var item = create_menu_item(action_name);
			if (item != null)
				menu.child_append(item);
		}
	}
	
	private Dbusmenu.Menuitem? create_menu_item(string action_name)
	{
		string? detailed_name = null;
		Diorite.Action? action = null;
		Diorite.RadioOption? option = null;
		if (!actions_reg.find_and_parse_action(action_name, out detailed_name, out action, out option))
		{
			warning("Action '%s' not found in registry.", action_name);
			return null;
		}
		
		string? label;
		string? icon;
		Variant? target;
		if (option != null)
		{
			label = option.label;
			icon = option.icon;
			target = option.parameter;
		}
		else
		{
			label = action.label;
			icon = action.icon;
			target = null;
		}
		
		var item = new Dbusmenu.Menuitem();
		item.property_set(Dbusmenu.MENUITEM_PROP_LABEL, label);
		item.property_set_bool(Dbusmenu.MENUITEM_PROP_ENABLED, action.enabled);
		if (action is Diorite.ToggleAction)
		{
			item.property_set(Dbusmenu.MENUITEM_PROP_TOGGLE_TYPE, Dbusmenu.MENUITEM_TOGGLE_CHECK);
			item.property_set_int(Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
			action.state.get_boolean() ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);
		}
		else if (action is Diorite.RadioAction)
		{
			item.property_set(Dbusmenu.MENUITEM_PROP_TOGGLE_TYPE, Dbusmenu.MENUITEM_TOGGLE_RADIO);
			item.property_set_int(Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
			action.state.equal(target) ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);
		}
		
		var adaptor = new ActionAdaptor(action, item, target);
		adaptors.prepend(adaptor);
		return item;
	}
	
	private void remove_menu()
	{
		if (dock_item != null && dock_item.quicklist != null)
		{
			clear_menu();
			dock_item.quicklist = null;
		}
	}
}

private class ActionAdaptor
{
	private Diorite.Action action;
	private Dbusmenu.Menuitem item;
	private Variant? parameter;
	
	public ActionAdaptor(Diorite.Action action, Dbusmenu.Menuitem item, Variant? parameter)
	{
		this.action = action;
		this.item = item;
		this.parameter = parameter;
		item.item_activated.connect(on_activated);
		action.notify.connect_after(on_action_changed);
	}
	
	~ActionAdaptor()
	{
		action.notify.disconnect(on_action_changed);
		item.item_activated.disconnect(on_activated);
	}
	
	private void on_activated(uint timestamp)
	{
		action.activate(parameter);
	}
	
	private void on_action_changed(GLib.Object o, ParamSpec p)
	{
		switch (p.name)
		{
		case "enabled":
			item.property_set_bool(Dbusmenu.MENUITEM_PROP_ENABLED, action.enabled);
			break;
		case "state":
			var state = action.state;
			if (state != null)
			{
				if (state.is_of_type(VariantType.BOOLEAN))
					item.property_set_int(Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
					state.get_boolean() ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);
				else
					item.property_set_int(Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
					action.state.equal(parameter) ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);
			}
			break;
		}
	}
}

} // namespace Nuvola
#endif
