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

private static const int ICON_SIZE = 48; 

public class WebAppListView : Gtk.IconView
{
	public WebAppListView(WebAppListModel model)
	{
		Object(pixbuf_column: WebAppListModel.Pos.ICON, text_column: WebAppListModel.Pos.NAME,
		item_padding: 5, row_spacing: 5, item_width: 3*ICON_SIZE/2,
		selection_mode: Gtk.SelectionMode.BROWSE);
		set_model(model);
	}
	
	public static Gdk.Pixbuf? load_icon(string? path, string fallback_icon)
	{
		if (path != null)
		{
			try
			{
				return new Gdk.Pixbuf.from_file_at_size(path, ICON_SIZE, ICON_SIZE);
			}
			catch(GLib.Error e)
			{
				warning("Failde to load icon '%s': %s", path, e.message);
			}
		}
		try
		{
			return Gtk.IconTheme.get_default().load_icon(fallback_icon, ICON_SIZE, 0);
		}
		catch (Error e)
		{
			var fallback2 = fallback_icon[0:fallback_icon.length - 1];
			warning("Unable to load fallback icon '%s'. %s. Trying '%s' instead.", fallback_icon, e.message, fallback2);
			
			try
			{
				return Gtk.IconTheme.get_default().load_icon(fallback2, ICON_SIZE, 0);
			}
			catch (Error e)
			{
				warning("Unable to load fallback icon '%s'. %s", fallback2, e.message);
			}
		}
		return null;
	}

}

} // namespace Nuvola
