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

public class WebAppListController : Diorite.Application
{
	public WebAppListWindow? main_window {get; private set; default = null;}
	public Diorite.Storage? storage {get; private set; default = null;}
	public WebAppRegistry? web_app_reg {get; private set; default = null;}
	public Diorite.ActionsRegistry? actions {get; private set; default = null;}
	private string? web_apps_dir = null;
	
	public WebAppListController(string? web_apps_dir)
	{
		base(UNIQUE_NAME, NAME, "%s.desktop".printf(APPNAME), APPNAME);
		icon = APP_ICON;
		version = VERSION;
		this.web_apps_dir = web_apps_dir;
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		main_window.present();
	}
	
	private void start()
	{
		append_actions();
		storage = new Diorite.XdgStorage.for_project(Nuvola.get_appname()).get_child("web_apps");
		if (web_apps_dir != null && web_apps_dir != "")
			web_app_reg = new WebAppRegistry.with_data_path(storage, web_apps_dir);
		else
			web_app_reg = new WebAppRegistry(storage, true);
		
		var web_apps = web_app_reg.list_web_apps();
		var model = new WebAppListModel();
		foreach (var web_app in web_apps.get_values())
			model.append_web_app(web_app, WebAppListView.load_icon(web_app.icon, APP_ICON));
	
		var view = new WebAppListView(model);
		main_window = new WebAppListWindow(this, view);
		set_app_menu(actions.build_menu({"quit"}));
		var menu = new Menu();
		set_menubar(menu);
		main_window.show_all();
	}
	
	private void append_actions()
	{
		actions = new Diorite.ActionsRegistry(this, null);
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.Action("main", "app", "quit", "Quit", "_Quit", "application-exit", "<ctrl>Q", on_quit),
		new Diorite.Action("main", "win", "menu", "Menu", null, "emblem-system-symbolic", null, null)
		};
		actions.add_actions(actions_spec);
		
	}
	
	private void on_quit()
	{
		quit();
	}
}

} // namespace Nuvola
