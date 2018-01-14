/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 * Main window of the Nuvola Master process
 */
public class MasterWindow : Drtgtk.ApplicationWindow
{
	/** Stack for the pages of the main window */
	public Gtk.Stack stack;
	private Gtk.StackSwitcher switcher;
	private new unowned MasterController app;
	
	/**
	 * Creates new MasterWindow for given app
	 */
	public MasterWindow(MasterController app)
	{
		base(app, false);
		try
		{
			icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
		}
		catch (Error e)
		{
			warning("Unable to load application icon.");
		}
		set_default_size(900, 600);
		this.app = app;
		update_title();
		create_toolbar({});
		stack = new Gtk.Stack();
		stack.notify["visible-child"].connect_after(update);
		switcher = new Gtk.StackSwitcher();
		switcher.set_stack(stack);
		header_bar.set_custom_title(switcher);
		switcher.show();
		top_grid.add(stack);
		stack.show_all();
	}
	
	/**
	 * Emitted when a page in the stack has changed
	 * 
	 * @param widget    Page widget
	 * @param name      Name of the page or null.
	 * @param title     Title of the page or null.
	 */
	public signal void page_changed(Gtk.Widget? widget, string? name, string? title);
	
	/**
	 * Add page to the main page stack
	 * 
	 * @param page     A widget to add.
	 * @param name     A page name.
	 * @param title    A title for the switcher.
	 */
	public void add_page(Gtk.Widget page, string name, string title)
	{
		var was_empty = stack.visible_child == null;
		stack.add_titled(page, name, title);
		if (was_empty)
			update();
	}
	
	private void update_title(string? title=null)
	{
		this.title = title != null ? "%s - %s".printf(title, app.app_name) : app.app_name;
	}
	
	private void update()
	{
		var child = stack.visible_child;
		string? name = null;
		string? title = null;
		if (child != null)
			stack.child_get(child, "name", out name, "title", out title);
		update_title(title);
		page_changed(child, name, title);
	}
}

} // namespace Nuvola
