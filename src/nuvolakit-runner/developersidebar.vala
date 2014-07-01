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

namespace Nuvola.Extensions.DeveloperSidebar
{

public Nuvola.ExtensionInfo get_info()
{
	return
	{
		_("Developer's sidebar"),
		Nuvola.get_version(),
		_("<p>This plugin shows data sent by integration script.</p>"),
		"Jiří Janoušek",
		typeof(Extension),
		true
	};
}

public class HeaderLabel: Gtk.Label
{
	public HeaderLabel(string? text)
	{
		Object(label: text);
		var text_attrs = new Pango.AttrList();
		text_attrs.change(Pango.attr_weight_new(Pango.Weight.BOLD));
		set_attributes(text_attrs);
		margin = 10;
	}
}

public class Extension : Nuvola.Extension
{
	private weak AppRunnerController controller;
	private WebEngine? web_engine;
	private Diorite.ActionsRegistry? actions_reg;
	private Gtk.Grid? grid = null;
	private Gtk.Label? song = null; 
	private Gtk.Label? artist = null;
	private Gtk.Label? album = null;
	private Gtk.Label? state = null;
	private SList<Gtk.Widget> action_widgets = null;
	private HashTable<string, Gtk.RadioButton>? radios = null;
	
	/**
	 * {@inheritDoc}
	 */
	public override void load(AppRunnerController controller) throws ExtensionError
	{
		this.controller = controller;
		web_engine = controller.web_engine;
		actions_reg = controller.actions;
		radios = new HashTable<string, Gtk.RadioButton>(str_hash, str_equal);
		grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		var label = new HeaderLabel("Song");
		label.halign = Gtk.Align.START;
		grid.add(label);
		song = new Gtk.Label(null);
		song.halign = Gtk.Align.START;
		grid.attach_next_to(song, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Artist");
		label.halign = Gtk.Align.START;
		grid.add(label);
		artist = new Gtk.Label(null);
		artist.halign = Gtk.Align.START;
		grid.attach_next_to(artist, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Album");
		label.halign = Gtk.Align.START;
		grid.add(label);
		album = new Gtk.Label(null);
		album.halign = Gtk.Align.START;
		grid.attach_next_to(album, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Playback state");
		label.halign = Gtk.Align.START;
		grid.add(label);
		state = new Gtk.Label(null);
		state.halign = Gtk.Align.START;
		grid.attach_next_to(state, label, Gtk.PositionType.BOTTOM, 1, 1);
		grid.show_all();
		
		controller.main_window.sidebar.add_page("developersidebar", _("Developer"), grid);
		controller.server.add_handler("Nuvola.MediaPlayer.sendDevelInfo", handle_send_devel_info);
	}
	
	/**
	 * {@inheritDoc}
	 */
	public override void unload()
	{
		controller.server.remove_handler("Nuvola.MediaPlayer.sendDevelInfo");
		if (grid != null)
		{
			controller.main_window.sidebar.remove_page(grid);
			grid = null;
		}
		action_widgets = null;
		radios = null;
	}
	
	private static string? variant_dict_str(Variant dict, string key)
	{
		var val = dict.lookup_value(key, null);
		if (val == null)
			return null;
		
		if (val.is_of_type(VariantType.MAYBE))
		{
			val = val.get_maybe();
			if (val == null)
				return null;
		}
			
		if (val.is_of_type(VariantType.VARIANT))
			val = val.get_variant();
		if (val.is_of_type(VariantType.STRING))
			return val.get_string();
		return null;
	}
	
	private Variant? handle_send_devel_info(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(@a{smv})");
		Variant dict;
		data.get("(@a{smv})", out dict);
		message("Song %s %s", dict.get_type_string(), dict.print(true));
		song.label = variant_dict_str(dict, "title") ?? "(null)";
		artist.label = variant_dict_str(dict, "artist") ?? "(null)";
		album.label = variant_dict_str(dict, "album") ?? "(null)";
		state.label = variant_dict_str(dict, "state") ?? "(null)";
		
		lock (action_widgets)
		{
			if (action_widgets != null)
				action_widgets.@foreach(unset_button);
			
			action_widgets = null;
			radios.remove_all();
			
			var label = new HeaderLabel("Base actions");
			label.halign = Gtk.Align.START;
			label.show();
			action_widgets.prepend(label);
			grid.add(label);
			var base_actions = Diorite.variant_to_strv(dict.lookup_value("baseActions", null).get_maybe().get_variant());
			foreach (var full_name in base_actions)
				add_action(full_name);
			
			label = new HeaderLabel("Extra actions");
			label.halign = Gtk.Align.START;
			label.show();
			action_widgets.prepend(label);
			grid.add(label);
			var extra_actions = Diorite.variant_to_strv(dict.lookup_value("extraActions", null).get_maybe().get_variant());
			foreach (var full_name in extra_actions)
				add_action(full_name);
		}
		
		return null;
	}
	
	private void add_action(string full_name)
	{
		Diorite.Action action;
		Diorite.RadioOption option;
		string detailed_name;
		if (actions_reg.find_and_parse_action(full_name, out detailed_name, out action, out option))
		{
			string action_name;
			Variant target_value;
			try
			{
				Action.parse_detailed_name(action.scope + "." + detailed_name, out action_name, out target_value);
			}
			catch (GLib.Error e)
			{
				critical("Failed to parse '%s': %s", action.scope + "." + detailed_name, e.message);
				return;
			}
			if (action is Diorite.SimpleAction)
			{
				var button = new Gtk.Button.with_label(action.label);
				button.action_name = action_name;
				button.action_target = target_value;
				button.margin = 2;
				button.show();
				action_widgets.prepend(button);
				grid.add(button);
			}
			else if (action is Diorite.ToggleAction)
			{
				var button = new Gtk.CheckButton.with_label(action.label);
				button.action_name = action_name;
				button.action_target = target_value;
				button.margin = 2;
				button.show();
				action_widgets.prepend(button);
				grid.add(button);
			}
			else if (action is Diorite.RadioAction)
			{
				var radio = radios.lookup(action.name);
				var button = new Gtk.RadioButton.with_label_from_widget(radio, option.label);
				if (radio == null)
				{
					radios.insert(action.name, button);
					action.notify["state"].connect_after(on_radio_action_changed);
				}
				button.margin = 2;
				button.show();
				action_widgets.prepend(button);
				grid.add(button);
				button.set_active(action.state.equal(target_value));
				button.set_data<string>("full-name", full_name);
				button.clicked.connect_after(on_radio_clicked);
			}
		}
	}
	
	private void on_radio_clicked(Gtk.Button button)
	{
		var radio = button as Gtk.RadioButton;
		var full_name = button.get_data<string>("full-name");
		Diorite.Action action;
		Diorite.RadioOption option;
		string detailed_name;
		if (actions_reg.find_and_parse_action(full_name, out detailed_name, out action, out option)
		&& !action.state.equal(option.parameter) && radio.active)
				action.activate(option.parameter);
	}
	
	private void on_radio_action_changed(GLib.Object o, ParamSpec p)
	{
		var action = o as Diorite.RadioAction;
		var state = action.state;
		var radio = radios.lookup(action.name);
		foreach (var item in radio.get_group())
		{
			var full_name = item.get_data<string>("full-name");
			Diorite.RadioOption option;
			if (actions_reg.find_and_parse_action(full_name, null, null, out option))
			{
				if (!item.active && state.equal(option.parameter))
					item.active = true;
			}
		}
	}
	
	private void unset_button(Gtk.Widget widget)
	{
		grid.remove(widget);
		var radio = widget as Gtk.RadioButton;
		if (radio != null)
		{
			radio.clicked.disconnect(on_radio_clicked);
			var full_name = radio.get_data<string>("full-name");
			Diorite.Action action;
			Diorite.RadioOption option;
			string detailed_name;
			if (actions_reg.find_and_parse_action(full_name, out detailed_name, out action, out option))
				action.notify["state"].disconnect(on_radio_action_changed);
		}
	}
}

} // namespace Nuvola.Extensions.DeveloperSidebar

