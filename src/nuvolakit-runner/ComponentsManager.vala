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

public class ComponentsManager: Gtk.ScrolledWindow
{
	public Diorite.SingleList<Component> components {get; construct;}
	private SList<Row> rows = null;
	private Gtk.Grid grid;

	public ComponentsManager(Diorite.SingleList<Component> components)
	{
		GLib.Object(components: components);
		grid = new Gtk.Grid();
		grid.margin = 10;
		grid.column_spacing = 10;
		refresh();
		add(grid);
	}
	
	public void refresh()
	{
		rows = null;
		foreach (var child in grid.get_children())
			grid.remove(child);
		
		var row = 0;
		foreach (var component in components)
		{
			if (row > 0)
			{
				var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
				separator.hexpand = true;
				separator.vexpand = false;
				separator.margin_top = separator.margin_bottom = 10;
				grid.attach(separator, 0, row++, 3, 1);
			}
			
			rows.prepend(new Row(grid, row++, component));
		}
		grid.show_all();
	}
	
	[Compact]
	private class Row
	{
		public unowned Component component;
		public Gtk.Button? button;
		public Gtk.Switch checkbox;
		
		public Row(Gtk.Grid grid, int row, Component component)
		{
			this.component = component;
			
			checkbox = new Gtk.Switch();
			checkbox.active = component.enabled;
			checkbox.vexpand = checkbox.hexpand = false;
			checkbox.halign = checkbox.valign = Gtk.Align.CENTER;
			component.notify.connect_after(on_notify);
			checkbox.notify.connect_after(on_notify);
			grid.attach(checkbox, 0, row, 1, 1);
			
			var label = new Gtk.Label(Markup.printf_escaped(
				"<span size='medium'><b>%s</b></span>\n<span foreground='#A19C9C' size='small'>%s</span>",
				component.name, component.description));
			label.use_markup = true;
			label.vexpand = false;
			label.hexpand = true;
			label.halign = Gtk.Align.START;
			label.set_line_wrap(true);
			grid.attach(label, 1, row, 1, 1);
			
			if (component.has_settings)
			{
				button = new Gtk.Button.from_icon_name("emblem-system-symbolic", Gtk.IconSize.BUTTON);
				button.vexpand = button.hexpand = false;
				button.halign = button.valign = Gtk.Align.CENTER;
				button.sensitive = component.enabled;
				button.clicked.connect(on_settings_clicked);
				grid.attach(button, 2, row, 1, 1);
			}
			else
			{
				button = null;
			}
		}
		
		~Row()
		{
			component.notify.disconnect(on_notify);
			checkbox.notify.disconnect(on_notify);
			if (button != null)
				button.clicked.disconnect(on_settings_clicked);
		}
		
		private void on_notify(GLib.Object o, ParamSpec p)
		{
			switch (p.name)
			{
			case "enabled":
				if (checkbox.active != component.enabled)
					checkbox.active = component.enabled;
				if (button != null)
					button.sensitive = checkbox.active;
				break;
			case "active":
				component.toggle(checkbox.active);
				break;
			}
		}
		
		private void on_settings_clicked()
		{
			warning("FIXME: ComponentsManager.Row.on_settings_clicked");
		}
	}
}

} // namespace Nuvola
