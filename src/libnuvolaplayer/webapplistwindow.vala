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

public class WebAppListWindow : Gtk.ApplicationWindow
{
	public Gtk.Grid grid {get; private set;}
	public WebAppListView view {get; private set;}
	public string? selected_web_app {get; private set; default = null;}
	private WebAppListController app;
	private Gtk.Grid details;
	private Gtk.Label app_name;
	private Gtk.Label app_version;
	private Gtk.Label app_maintainer;
	
	public WebAppListWindow(WebAppListController app, WebAppListView view)
	{
		title = "Services - " + app.app_name;
		try
		{
			icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
		}
		catch (Error e)
		{
			warning("Unable to load application icon.");
		}
		set_default_size(500, 500);
		
		this.app = app;
		app.add_window(this);
		app.actions.window = this;
		app.actions.get_action(Actions.REMOVE_APP).enabled = false;
		app.actions.get_action(Actions.START_APP).enabled = false;
		this.view = view;
		view.selection_changed.connect(on_selection_changed);
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.add(view);
		scroll.vexpand = true;
		scroll.hexpand = true;
		var toolbar = app.actions.build_toolbar({Actions.START_APP, "|", Actions.INSTALL_APP, Actions.REMOVE_APP, " ", Actions.MENU});
		toolbar.get_style_context().add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
		toolbar.hexpand = true;
		toolbar.vexpand = false;
		
		details = new Gtk.Grid();
		details.orientation = Gtk.Orientation.HORIZONTAL;
		details.halign = Gtk.Align.CENTER;
		var label = new Gtk.Label("<b>Name:</b>");
		label.hexpand = label.vexpand = false;
		label.use_markup = true;
		label.margin = 5;
		details.add(label);
		app_name = new Gtk.Label(null);
		app_name.vexpand = false;
		app_name.hexpand = false;
		details.attach_next_to(app_name, label, Gtk.PositionType.RIGHT, 1, 1);
		label = new Gtk.Label("<b>Version:</b>");
		label.hexpand = label.vexpand = false;
		label.use_markup = true;
		label.margin = 5;
		details.add(label);
		app_version = new Gtk.Label(null);
		app_version.vexpand = false;
		app_version.hexpand = false;
		details.attach_next_to(app_version, label, Gtk.PositionType.RIGHT, 1, 1);
		label = new Gtk.Label("<b>Maintainer:</b>");
		label.hexpand = label.vexpand = false;
		label.use_markup = true;
		label.margin = 5;
		details.add(label);
		app_maintainer = new Gtk.Label(null);
		app_maintainer.vexpand = false;
		app_maintainer.hexpand = false;
		app_maintainer.use_markup = true;
		details.attach_next_to(app_maintainer, label, Gtk.PositionType.RIGHT, 1, 1);
		details.show_all();
		details.hide();
		details.no_show_all = true;
		
		grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		grid.add(toolbar);
		grid.add(scroll);
		grid.add(details);
		add(grid);
		
		view.select_path(new Gtk.TreePath.first());
	}
	
	private void on_selection_changed()
	{
		var items = view.get_selected_items();
		Gtk.TreePath? path = null;
		foreach (var my_path in items)
			path = my_path;
		
		if (path == null)
		{
			details.hide();
			selected_web_app = null;
			app.actions.get_action(Actions.REMOVE_APP).enabled = false;
			app.actions.get_action(Actions.START_APP).enabled = false;
			return;
		}
		
		
		var model = view.get_model();
		Gtk.TreeIter iter;
		if (!model.get_iter(out iter, path))
		{
			details.hide();
			selected_web_app = null;
			app.actions.get_action(Actions.REMOVE_APP).enabled = false;
			app.actions.get_action(Actions.START_APP).enabled = false;
			return;
		}
		
		string id;
		string name;
		string version;
		string maintainer_name;
		string maintainer_link;
		bool removable;
		model.get(iter,
			WebAppListModel.Pos.ID, out id,
			WebAppListModel.Pos.NAME, out name,
			WebAppListModel.Pos.VERSION, out version,
			WebAppListModel.Pos.MAINTAINER_NAME, out maintainer_name,
			WebAppListModel.Pos.MAINTAINER_LINK, out maintainer_link,
			WebAppListModel.Pos.REMOVABLE, out removable
		);
		
		selected_web_app = id;
		app_version.label = version;
		app_name.label = name;
		app_maintainer.label = "<a href=\"%s\">%s</a>".printf(
		Markup.escape_text(maintainer_link), Markup.escape_text(maintainer_name));
		details.show();
		app.actions.get_action(Actions.REMOVE_APP).enabled = removable;
		app.actions.get_action(Actions.START_APP).enabled = true;
	}
	

}

} // namespace Nuvola
