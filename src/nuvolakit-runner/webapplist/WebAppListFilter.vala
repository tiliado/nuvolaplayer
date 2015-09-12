/*
 * Copyright 2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WebAppListFilter : Gtk.TreeModelFilter
{
	public string? category {get; set; default = null;}
	public bool show_hidden {get; set; default = false;}
	
	public WebAppListFilter(WebAppListModel model, bool show_hidden=false, string? category=null)
	{
		Object(child_model: model, category: category, show_hidden: show_hidden);
		set_visible_func(visible_func);
		notify.connect_after(on_notify);
	}
	
	private bool visible_func(Gtk.TreeModel model, Gtk.TreeIter iter)
	{
		WebAppMeta web_app = null;
		model.get(iter, WebAppListModel.Pos.META, out web_app);
		assert(web_app != null);
		if (!show_hidden && web_app.hidden)
			return false;
		if (category == null)
			return true;
		return web_app.in_category(category);
	}
	
	private void on_notify(GLib.Object o, ParamSpec param)
	{
		assert(this == o);
		switch (param.name)
		{
		case "category":
		case "show-hidden":
			refilter();
			break;
		}
	}
}

} // namespace Nuvola
