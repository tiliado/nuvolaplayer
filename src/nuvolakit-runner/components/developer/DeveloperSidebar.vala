/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class DeveloperSidebar: Gtk.ScrolledWindow
{
	private Diorite.Actions? actions_reg;
	private Gtk.Grid grid;
	private Gtk.Image? artwork = null;
	private Gtk.Label? song = null; 
	private Gtk.Label? artist = null;
	private Gtk.Label? album = null;
	private Gtk.Label? state = null;
	private Gtk.Label? rating = null;
	private SList<Gtk.Widget> action_widgets = null;
	private HashTable<string, Gtk.RadioButton>? radios = null;
	private MediaPlayerModel player;
	
	public DeveloperSidebar(RunnerApplication app, MediaPlayerModel player)
	{
		vexpand = true;
		actions_reg = app.actions;
		this.player = player;
		radios = new HashTable<string, Gtk.RadioButton>(str_hash, str_equal);
		grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		grid.hexpand = grid.vexpand = true;
		artwork = new Gtk.Image();
		clear_artwork(false);
		grid.add(artwork);
		var label = new HeaderLabel("Song");
		label.halign = Gtk.Align.START;
		grid.attach_next_to(label, artwork, Gtk.PositionType.BOTTOM, 1, 1);
		song = new Gtk.Label(player.title ?? "(null)");
		song.set_line_wrap(true);
		song.halign = Gtk.Align.START;
		grid.attach_next_to(song, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Artist");
		label.halign = Gtk.Align.START;
		grid.add(label);
		artist = new Gtk.Label(player.artist ?? "(null)");
		artist.set_line_wrap(true);
		artist.halign = Gtk.Align.START;
		grid.attach_next_to(artist, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Album");
		label.halign = Gtk.Align.START;
		grid.add(label);
		album = new Gtk.Label(player.album);
		album.set_line_wrap(true);
		album.halign = Gtk.Align.START;
		grid.attach_next_to(album, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Playback state");
		label.halign = Gtk.Align.START;
		grid.add(label);
		state = new Gtk.Label(player.state);
		state.halign = Gtk.Align.START;
		grid.attach_next_to(state, label, Gtk.PositionType.BOTTOM, 1, 1);
		label = new HeaderLabel("Rating");
		label.halign = Gtk.Align.START;
		grid.add(label);
		rating = new Gtk.Label(player.rating >= 0.0 ? player.rating.to_string() : "(null)");
		rating.halign = Gtk.Align.START;
		grid.attach_next_to(rating, label, Gtk.PositionType.BOTTOM, 1, 1);
		set_actions(player.playback_actions);
		
		add(grid);
		show_all();
		
		player.notify.connect_after(on_player_notify);
	}
	
	~DeveloperSidebar()
	{	
		player.notify.disconnect(on_player_notify);
		action_widgets = null;
		radios = null;
	}
	
	private void clear_artwork(bool broken)
	{
		try
		{
			var icon_name = broken ? "dialog-error": "audio-x-generic";
			var pixbuf = Gtk.IconTheme.get_default().load_icon(icon_name, 80, Gtk.IconLookupFlags.FORCE_SIZE);
			artwork.set_from_pixbuf(pixbuf);
		}
		catch (GLib.Error e)
		{
			warning("Pixbuf error: %s", e.message);
			artwork.clear();
		}
	}
	
	private void on_player_notify(GLib.Object o, ParamSpec p)
	{
		var player = o as MediaPlayerModel;
		switch (p.name)
		{
		case "artwork-file":
			if (player.artwork_file == null)
			{
				clear_artwork(false);
			}
			else
			{
				try
				{
					var pixbuf = new Gdk.Pixbuf.from_file_at_scale(player.artwork_file, 80, 80, true);
					artwork.set_from_pixbuf(pixbuf);
				}
				catch (GLib.Error e)
				{
					warning("Pixbuf error: %s", e.message);
					clear_artwork(true);
				}
			}
			break;
		case "title":
			song.label = player.title ?? "(null)";
			break;
		case "artist":
			artist.label = player.artist ?? "(null)";
			break;
		case "album":
			album.label = player.album ?? "(null)";
			break;
		case "state":
			state.label = player.state ?? "(null)";
			break;
		case "rating":
			rating.label = player.rating >= 0.0 ? player.rating.to_string() : "(null)";
			break;
		case "playback-actions":
			set_actions(player.playback_actions);
			break;
		default:
			debug("Media player notify: %s", p.name);
			break;
		}
	}
	
	private void set_actions(SList<string> playback_actions)
	{
		lock (action_widgets)
		{
			if (action_widgets != null)
				action_widgets.@foreach(unset_button);
			
			action_widgets = null;
			radios.remove_all();
			
			var label = new HeaderLabel("Playback Actions");
			label.halign = Gtk.Align.START;
			label.show();
			action_widgets.prepend(label);
			grid.add(label);
			
			foreach (var full_name in playback_actions)
				add_action(full_name);
			
		}
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
				GLib.Action.parse_detailed_name(action.scope + "." + detailed_name, out action_name, out target_value);
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

} // namespace Nuvola

