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

public class WebAppWindow : Gtk.ApplicationWindow
{
	public Gtk.Grid grid {get; private set;}
	public bool maximized {get; private set; default = false;}
	private Gtk.MenuBar? _menu_bar = null;
	public Gtk.MenuBar? menu_bar
	{
		get
		{
			return _menu_bar;
		}
		set
		{
			if (_menu_bar != null)
			{
				grid.remove(_menu_bar);
				grid.remove_row(0);
			}
			_menu_bar = value;
			if (_menu_bar != null)
			{
				grid.insert_row(0);
				grid.attach(_menu_bar, 0, 0, 1, 1);
				_menu_bar.show();
			}
		}
	}
	
	private WebAppController app;
	
	public WebAppWindow(WebAppController app)
	{
		Object(show_menubar: false);
		window_state_event.connect(on_window_state_event);
		title = app.app_name;
		try
		{
			icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
		}
		catch (Error e)
		{
			warning("Unable to load application icon.");
		}
		set_default_size(500, 500);
		
		delete_event.connect(on_delete_event);
		
		this.app = app;
		app.add_window(this);
		app.actions.window = this;
		grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		add(grid);
	}
	
	public signal void can_destroy(ref bool result);
	
	public bool on_delete_event(Gdk.EventAny event)
	{
		hide();
		bool result = true;
		can_destroy(ref result);
		return !result;
	}
	
	private bool on_window_state_event(Gdk.EventWindowState event)
	{
		maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
		return false;
	}
}

} // namespace Nuvola
