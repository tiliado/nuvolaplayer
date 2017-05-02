/*
 * Copyright 2011-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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
#if APPINDICATOR
namespace Nuvola
{

public class Appindicator: GLib.Object
{
	public bool visible {get; private set; default = false;}
	private AppRunnerController controller;
	private Diorite.Actions actions;
	private LauncherModel model;
	private Gtk.Menu? menu = null;
	private AppIndicator.Indicator? indicator = null;
	
	public Appindicator(AppRunnerController controller, LauncherModel model)
	{
		this.controller = controller;
		this.actions = controller.actions;
		this.model = model;
		model.notify.connect_after(on_model_changed);
		warning("AppIndicator support is experimental.");
		indicator = new AppIndicator.Indicator(
			controller.web_app.id, controller.icon, AppIndicator.IndicatorCategory.APPLICATION_STATUS);
		indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
		indicator.title = controller.app_name;
		create_menu();
	}
	
	private void on_model_changed(GLib.Object o, ParamSpec p)
	{
		switch (p.name)
		{
		case "actions":
			create_menu();
			break;
		}
	}
	
	~Appindicator()
	{
		indicator = null;
		model.notify.disconnect(on_model_changed);
		menu = null;
	}
	
	private void create_menu()
	{
		if (menu != null)
		{
			menu.@foreach((child) =>
			{
				var item = child as Gtk.MenuItem;
				if (item != null)
					item.activate.disconnect(on_menu_item_activated);
				});
		}
		
		menu = new Gtk.Menu();
		add_menu_item_for_action("activate");
		foreach (unowned string name in model.actions)
			add_menu_item_for_action(name);
		menu.show();
		indicator.set_menu(menu);
	}
	
	private void add_menu_item_for_action(string name)
	{
		Diorite.Action action = null;
		string? detailed_name = null;
		Diorite.RadioOption? option = null;
		if (!actions.find_and_parse_action(name, out detailed_name, out action, out option))
		{
			warning("Action %s not found", name);
			return;
		}
		Gtk.MenuItem item;
		if (action is Diorite.SimpleAction)
		{
			item = new Gtk.MenuItem.with_label(action.label);
		}
		else
		{
			item = null;
			warning("%s %s is not supported yet.", action.get_type().name(), name);
			return;
		}
		
		item.set_data<string>("diorite_action", name);
		item.activate.connect(on_menu_item_activated);
		item.show();
		menu.add(item);
	}
	
	private void on_menu_item_activated(Gtk.MenuItem item)
	{
		var name = item.get_data<string>("diorite_action");
		return_if_fail(name != null);
		var action = actions.get_action(name);
		return_if_fail(action != null);
		action.activate(null);
	}
}

} // namespace Nuvola
#endif
