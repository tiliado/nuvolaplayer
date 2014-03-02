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

public void main(string[] args)
{
	Gtk.init(ref args);
	var main_window = new Gtk.Window();
	main_window.set_default_size(400, 400);
	
	var storage = new Diorite.XdgStorage.for_project(Nuvola.get_appname()).get_child("web_apps");
	var web_app_reg = new WebAppRegistry.with_data_path(storage, "./data/nuvolaplayer3/web_apps");
	var web_apps = web_app_reg.list_web_apps();
	var model = new WebAppListModel();
	foreach (var web_app in web_apps.get_values())
		model.append_web_app(web_app, WebAppListView.load_icon(web_app.icon, "nuvolaplayer"));

	var view = new WebAppListView(model);
	var scroll = new Gtk.ScrolledWindow(null, null);
	scroll.add(view);
	main_window.add(scroll);
	main_window.show_all();
	main_window.delete_event.connect((a) => {Gtk.main_quit(); return false;});
	view.select_path(new Gtk.TreePath.first());
	Gtk.main();
}

} // namespace Nuvola


