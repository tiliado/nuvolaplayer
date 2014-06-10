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
	public const string START_APP = "start-app";
	public const string INSTALL_APP = "install-app";
	public const string REMOVE_APP = "remove-app";
	public const string MENU = "menu";
	public const string QUIT = "quit";
}

public class WebAppListController : Diorite.Application
{
	public WebAppListWindow? main_window {get; private set; default = null;}
	public Diorite.Storage storage {get; private set; default = null;}
	public WebAppRegistry web_app_reg {get; private set; default = null;}
	public Diorite.ActionsRegistry? actions {get; private set; default = null;}
	public weak Gtk.Settings gtk_settings {get; private set;}
	private string[] exec_cmd;
	private Gtk.Menu pop_down_menu;
	
	public WebAppListController(Diorite.Storage storage, WebAppRegistry web_app_reg, string[] exec_cmd)
	{
		var app_name = Nuvola.get_appname();
		base(Nuvola.get_unique_name(), Nuvola.get_display_name(), "%s.desktop".printf(app_name), app_name);
		flags = flags|ApplicationFlags.HANDLES_COMMAND_LINE;
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
		this.storage = storage;
		this.web_app_reg = web_app_reg;
		this.exec_cmd = exec_cmd;
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		
		main_window.show_all();
		main_window.present();
	}
	
	private void start()
	{
		gtk_settings = Gtk.Settings.get_default();
		append_actions();
		actions.get_action(Actions.INSTALL_APP).enabled = web_app_reg.allow_management;
		
		var model = new WebAppListModel(web_app_reg);
	
		var view = new WebAppListView(model);
		main_window = new WebAppListWindow(this, view);
		
		if (app_menu_shown)
			set_app_menu(actions.build_menu({Actions.QUIT}));
		
		if (menubar_shown)
		{
			var menu = new Menu();
			menu.append_submenu("_Apps", actions.build_menu({Actions.START_APP, "|", Actions.INSTALL_APP, Actions.REMOVE_APP}));
			set_menubar(menu);
		}
		
		var pop_down_model = actions.build_menu({Actions.QUIT});
		pop_down_menu = new Gtk.Menu.from_model(pop_down_model);
		pop_down_menu.attach_to_widget(main_window, null);
		
	}
	
	public override int command_line(ApplicationCommandLine command_line)
	{
		hold();
		var result = handle_command_line(command_line);
		release();
		return result;
	}
	
	
	private int handle_command_line(ApplicationCommandLine command_line)
	{
		string? app_id = null;
		OptionEntry[] options = new OptionEntry[1];
		options[0] = { "app-id", 'a', 0, OptionArg.STRING, ref app_id, "Web app to run.", "ID" };
		
		// We have to make an extra copy of the array, since .parse assumes
		// that it can remove strings from the array without freeing them.
		string[] args = command_line.get_arguments();
		string*[] _args = new string[args.length];
		for (int i = 0; i < args.length; i++)
			_args[i] = args[i];
		
		try
		{
			var opt_context = new OptionContext("- Nuvola Player");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			unowned string[] tmp = _args;
			opt_context.parse(ref tmp);
		}
		catch (OptionError e)
		{
			command_line.print("option parsing failed: %s\n", e.message);
			return 1;
		}
		
		if (main_window == null)
			start();
		
		if (app_id != null)
		{
			main_window.hide();
			start_app(app_id);
		}
		else
		{
			activate();
		}
		
		return 0;
	}
	
	private void append_actions()
	{
		actions = new Diorite.ActionsRegistry(this, null);
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.SimpleAction("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		new Diorite.SimpleAction("main", "win", Actions.MENU, "Menu", null, "emblem-system-symbolic", null, do_menu),
		new Diorite.SimpleAction("main", "win", Actions.START_APP, "Start app", "_Start app", "media-playback-start", "<ctrl>S", do_start_app),
		new Diorite.SimpleAction("main", "win", Actions.INSTALL_APP, "Install app", "_Install app", "list-add", "<ctrl>plus", do_install_app),
		new Diorite.SimpleAction("main", "win", Actions.REMOVE_APP, "Remove app", "_Remove app", "list-remove", "<ctrl>minus", do_remove_app)
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
			catch (WebAppError e)
			{
				var error = new Diorite.ErrorDialog(("Installation failed"),
					("Installation of service from package %s failed.").printf(file.get_path())
					+ "\n\n" + e.message);
				error.run();
			}
		}
	}
	
	private void do_remove_app()
	{
		if (main_window.selected_web_app == null)
			return;
		
		var web_app = web_app_reg.get_app(main_window.selected_web_app);
		if (web_app == null)
			return;
		try
		{
			web_app_reg.remove_app(web_app);
			var meta = web_app.meta;
			var info = new Diorite.InfoDialog(("Removal successfull"),
				("Service %1$s (version %2$d.%3$d) has been succesfuly removed").printf(meta.name, meta.version_major, meta.version_minor));
			info.run();
		}
		catch (WebAppError e)
		{
			var error = new Diorite.ErrorDialog(("Removal failed"),
				_("Removal of service %s failed.").printf(web_app.meta.name)
				+ "\n\n" + e.message);
			error.run();
		}
	}
	
	private void do_menu()
	{
		var event = Gtk.get_current_event();
		pop_down_menu.popup(null, null, null, event.button.button, event.button.time);
	}
	
	private void do_start_app()
	{
		if (main_window.selected_web_app == null)
			return;
		
		main_window.hide();
		start_app(main_window.selected_web_app);
	}
	
	private void start_app(string app_id)
	{
		string[] argv = new string[exec_cmd.length + 2];
		for (var i = 0; i < exec_cmd.length; i++)
			argv[i] = exec_cmd[i];
		argv[exec_cmd.length] = app_id;
		argv[exec_cmd.length + 1] = null;
		
		try
		{
			new Diorite.Subprocess(argv, Diorite.SubprocessFlags.INHERIT_FDS);
		}
		catch (GLib.Error e)
		{
			warning("Failed to launch subproccess. %s", e.message);
		}
	
		
	}
}

} // namespace Nuvola
