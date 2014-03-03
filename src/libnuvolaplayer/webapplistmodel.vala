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

public class WebAppListModel : Gtk.ListStore
{
	public enum Pos
	{
		ID, NAME, ICON, VERSION, MAINTAINER_NAME, MAINTAINER_LINK, REMOVABLE;
	}
	
	public WebAppListModel()
	{
		Object();
		//                         id            name            icon                version  maintainer_name maintainer_link    removable
		set_column_types({typeof(string), typeof(string), typeof(Gdk.Pixbuf), typeof(string), typeof(string), typeof(string), typeof(bool)});
	}
	
	public void append_web_app(WebApp web_app, Gdk.Pixbuf? icon)
	{
		Gtk.TreeIter iter;
		append(out iter);
		@set(iter,
		Pos.ID, web_app.meta.id,
		Pos.NAME, web_app.meta.name,
		Pos.ICON, icon,
		Pos.VERSION, "%d.%d".printf(web_app.meta.version_major, web_app.meta.version_minor),
		Pos.MAINTAINER_NAME, web_app.meta.maintainer_name,
		Pos.MAINTAINER_LINK, web_app.meta.maintainer_link,
		Pos.REMOVABLE, web_app.removable,
		-1);
	}
}

} // namespace Nuvola
