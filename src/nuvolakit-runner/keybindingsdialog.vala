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


public class KeybindingsDialog : Gtk.Dialog
{
	/// Preferences dialog title
	private const string TITLE = ("Keyboard shortcuts");
	private Diorite.Application app;
	private Diorite.ActionsRegistry actions_reg;
	private Config config;
	private ActionsKeyBinder global_keybindings;
	private Gtk.TreeView view;
	private Gtk.ListStore model;
	
	/**
	 * Constructs new main window
	 * 
	 * @param app Application object
	 */
	public KeybindingsDialog(Diorite.Application app, Gtk.Window? parent, Diorite.ActionsRegistry actions_reg,
	Config config, ActionsKeyBinder global_keybindings)
	{
		this.app = app;
		this.actions_reg = actions_reg;
		this.config = config;
		this.global_keybindings = global_keybindings;
		
		window_position = Gtk.WindowPosition.CENTER;
		title = TITLE;
		border_width = 5;
		try
		{
			icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
		}
		catch (Error e)
		{
			warning("Unable to load application icon.");
		}
		
		set_default_size(400, 400);
		
		if (parent != null)
			set_transient_for(parent);
		modal = true;
		
		add_buttons(Gtk.Stock.CLOSE, Gtk.ResponseType.CLOSE);
		
		model = new Gtk.ListStore(6, typeof(string), typeof(string), typeof(uint), typeof(Gdk.ModifierType), typeof(uint), typeof(Gdk.ModifierType));
		Gtk.TreeIter iter;
		foreach (var action in actions_reg.list_actions())
		{
			var label = action.label;
			if (action is Diorite.RadioAction || label == null)
				continue;
			
			var keybinding = action.keybinding;
			uint accel_key;
			Gdk.ModifierType accel_mods;
			if (keybinding != null)
			{
				Gtk.accelerator_parse(keybinding, out accel_key, out accel_mods);
			}
			else
			{
				accel_key = 0;
				accel_mods = 0;
			}

			keybinding = global_keybindings.get_keybinding(action.name);
			uint glob_accel_key;
			Gdk.ModifierType glob_accel_mods;
			if (keybinding != null)
			{
				Gtk.accelerator_parse(keybinding, out glob_accel_key, out glob_accel_mods);
			}
			else
			{
				glob_accel_key = 0;
				glob_accel_mods = 0;
			}
			
			model.append(out iter);
			model.set(iter, 0, action.name, 1, label, 2, accel_key, 3, accel_mods, 4, glob_accel_key, 5, glob_accel_mods, -1);
		}
		
		view = new Gtk.TreeView.with_model(model);
		
		var cell = new Gtk.CellRendererText();
		view.insert_column_with_attributes(-1, "Action", cell, "text", 1);
		
		var accel_cell = new Gtk.CellRendererAccel();
		accel_cell.editable = true;
		accel_cell.accel_mode = Gtk.CellRendererAccelMode.GTK;
		accel_cell.accel_edited.connect(on_accel_edited);
		accel_cell.accel_cleared.connect(on_accel_cleared);
		view.insert_column_with_attributes(-1, "Shortcut", accel_cell, "accel-key", 2, "accel-mods", 3);
		
		accel_cell = new Gtk.CellRendererAccel();
		accel_cell.editable = true;
		accel_cell.accel_mode = Gtk.CellRendererAccelMode.GTK;
		accel_cell.accel_edited.connect(on_glob_accel_edited);
		accel_cell.accel_cleared.connect(on_glob_accel_cleared);
		view.insert_column_with_attributes(-1, "Global Shortcut", accel_cell, "accel-key", 4, "accel-mods", 5);
		
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.vexpand = scroll.hexpand = true;
		scroll.add(view);
		scroll.show();
		get_content_area().add(scroll);
		view.show();
	}
	
	public override bool delete_event(Gdk.EventAny event)
	{
		return false;
	}
	
	private void on_accel_edited(string path_string, uint accel_key, Gdk.ModifierType accel_mods, uint hardware_keycode)
	{
		var keybinding = Gtk.accelerator_name(accel_key, accel_mods);
		var path = new Gtk.TreePath.from_string(path_string);
		Gtk.TreeIter iter;
		model.get_iter(out iter, path);
		model.set(iter, 2, accel_key, 3, accel_mods, -1);
		string name;
		model.get(iter, 0, out name, -1);
		message("nuvola.keybindings.%s %s", name, Gtk.accelerator_name(accel_key, accel_mods));
		config.set_string("nuvola.keybindings." + name, keybinding);
		var action = actions_reg.get_action(name);
		return_if_fail(action != null);
		action.keybinding = keybinding;
	}
	
	private void on_accel_cleared(string path_string)
	{
		var path = new Gtk.TreePath.from_string(path_string);
		Gtk.TreeIter iter;
		model.get_iter(out iter, path);
		model.set(iter, 2, 0, 3, 0, -1);
		string name;
		model.get(iter, 0, out name, -1);
		config.set_string("nuvola.keybindings." + name, "");
		var action = actions_reg.get_action(name);
		return_if_fail(action != null);
		action.keybinding = null;
	}
	
	private void on_glob_accel_edited(string path_string, uint accel_key, Gdk.ModifierType accel_mods, uint hardware_keycode)
	{
		var keybinding = Gtk.accelerator_name(accel_key, accel_mods);
		var path = new Gtk.TreePath.from_string(path_string);
		Gtk.TreeIter iter;
		model.get_iter(out iter, path);
		string name;
		model.get(iter, 0, out name, -1);
		message("nuvola.global_keybindings.%s %s", name, Gtk.accelerator_name(accel_key, accel_mods));
		
		
		if (global_keybindings.set_keybinding(name, keybinding))
			model.set(iter, 4, accel_key, 5, accel_mods, -1);
		else
			model.set(iter, 4, 0, 5, 0, -1);
	}
	
	private void on_glob_accel_cleared(string path_string)
	{
		var path = new Gtk.TreePath.from_string(path_string);
		Gtk.TreeIter iter;
		model.get_iter(out iter, path);
		string name;
		model.get(iter, 0, out name, -1);
		global_keybindings.set_keybinding(name, null);
		model.set(iter, 4, 0, 5, 0, -1);
	}
}

} // namespace Nuvola
