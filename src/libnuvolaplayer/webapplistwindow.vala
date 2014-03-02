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
		set_default_size(400, 400);
		
		app.add_window(this);
		app.actions.window = this;
		this.view = view;
		view.select_path(new Gtk.TreePath.first());
		var scroll = new Gtk.ScrolledWindow(null, null);
		scroll.add(view);
		scroll.vexpand = true;
		scroll.hexpand = true;
		var toolbar = app.actions.build_toolbar({"quit", " ", "menu"});
		toolbar.hexpand = true;
		toolbar.vexpand = false;
		
		grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		grid.add(toolbar);
		grid.add(scroll);
		add(grid);
	}

}

} // namespace Nuvola
