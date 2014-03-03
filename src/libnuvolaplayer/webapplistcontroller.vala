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

namespace Actions
{
	public const string INSTALL_APP = "install-app";
	public const string REMOVE_APP = "remove-app";
	public const string MENU = "menu";
	public const string QUIT = "quit";
}

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
		
		actions.get_action(Actions.INSTALL_APP).enabled = web_app_reg.allow_management;
		
		var model = new WebAppListModel(web_app_reg);
	
		var view = new WebAppListView(model);
		main_window = new WebAppListWindow(this, view);
		set_app_menu(actions.build_menu({Actions.QUIT}));
		var menu = new Menu();
		menu.append_submenu("_Apps", actions.build_menu({Actions.INSTALL_APP, Actions.REMOVE_APP}));
		set_menubar(menu);
		main_window.show_all();
	}
	
	private void append_actions()
	{
		actions = new Diorite.ActionsRegistry(this, null);
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.Action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		new Diorite.Action("main", "win", Actions.MENU, "Menu", null, "emblem-system-symbolic", null, null),
		new Diorite.Action("main", "win", Actions.INSTALL_APP, "Install app", "_Install app", "list-add", "<ctrl>plus", do_install_app),
		new Diorite.Action("main", "win", Actions.REMOVE_APP, "Remove app", "_Remove app", "list-remove", "<ctrl>minus", null)
		};
		actions.add_actions(actions_spec);
		
	}
	
	private void do_quit()
	{
		quit();
	}
	
	private void do_install_app()
	{
		var dialog = new Gtk.FileChooserDialog(("Choose service integration package"),
			main_window, Gtk.FileChooserAction.OPEN, Gtk.Stock.CANCEL,
			Gtk.ResponseType.CANCEL, Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT
		);
		dialog.set_default_size(400, -1);
		var response = dialog.run();
		var file = dialog.get_file();
		dialog.destroy();
		
		if (response == Gtk.ResponseType.ACCEPT)
		{
			try
			{
				var app = web_app_reg.install_app(file);
				var meta = app.meta;
				var info = new Diorite.InfoDialog(("Installation successfull"),
					("Service %1$s (version %2$d.%3$d) has been installed succesfuly").printf(meta.name, meta.version_major, meta.version_minor));
				
//~ 				reload(service.id);
				info.run();
			}
			catch(WebAppError e){
				var error = new Diorite.ErrorDialog(("Installation failed"),
					("Installation of service from package %s failed.").printf(file.get_path())
					+ "\n\n" + e.message);
				error.run();
			}
		}
	}
}

} // namespace Nuvola
