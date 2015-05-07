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


public class PreferencesDialog : Gtk.Dialog
{
	/// Preferences dialog title
	private const string TITLE = ("Preferences");
	private Diorite.Application app;
	private Gtk.Notebook notebook;
	
	/**
	 * Constructs new main window
	 * 
	 * @param app Application object
	 */
	public PreferencesDialog(Diorite.Application app, Gtk.Window? parent, Diorite.Form form)
	{
		this.app = app;
		
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
		
		set_default_size(600, -1);
		
		if (parent != null)
			set_transient_for(parent);
		modal = true;
		
		add_buttons("Cancel", Gtk.ResponseType.CLOSE, "Save changes", Gtk.ResponseType.OK);
		notebook = new Gtk.Notebook();
		notebook.margin_bottom = 10;
		notebook.tab_pos = Gtk.PositionType.LEFT;
		form.show();
		notebook.append_page(form, new Gtk.Label("Preferences"));
		get_content_area().add(notebook);
		form.check_toggles();
		notebook.show();
	}
	
	public void add_tab(string label, Gtk.Widget widget)
	{
		widget.show();
		notebook.append_page(widget, new Gtk.Label(label));
	}
	
	public override bool delete_event(Gdk.EventAny event)
	{
		return false;
	}
}

} // namespace Nuvola
