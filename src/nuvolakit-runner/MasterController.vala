/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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
	public const string QUIT = "quit";
	public const string CREATE_LAUNCHERS = "create-launchers";
	public const string DELETE_LAUNCHERS = "delete-launchers";
}

public string build_master_ipc_id()
{
	return Nuvola.get_app_id() + ".master";
}

public class MasterController : Diorite.Application
{
	public WebAppListWindow? main_window {get; private set; default = null;}
	public Diorite.Storage storage {get; private set; default = null;}
	public WebAppRegistry web_app_reg {get; private set; default = null;}
	private string[] exec_cmd;
	private Queue<AppRunner> app_runners = null;
	private HashTable<string, AppRunner> app_runners_map = null;
	private MasterBus server = null;
	private Config config = null;
	private Diorite.KeyValueStorageServer storage_server = null;
	private ActionsKeyBinderServer actions_key_binder = null;
	private MediaKeysServer media_keys = null;
	#if EXPERIMENTAL
	private HttpRemoteControl.Server http_remote_control = null;
	#endif
	private InitState init_state = InitState.NONE;
	private bool debuging;
	
	public MasterController(Diorite.Storage storage, WebAppRegistry web_app_reg, string[] exec_cmd, bool debuging=false)
	{
		var app_id = Nuvola.get_app_id();
		base(Nuvola.get_app_uid(), Nuvola.get_app_name(), "%s.desktop".printf(app_id), app_id, ApplicationFlags.HANDLES_COMMAND_LINE);
		icon = Nuvola.get_app_icon();
		version = Nuvola.get_version();
		this.storage = storage;
		this.web_app_reg = web_app_reg;
		this.exec_cmd = exec_cmd;
		this.debuging = debuging;
	}
	
	public override void activate()
	{
		hold();
		if (main_window == null)
		{
			create_main_window();
			main_window.category = "Audio";
		}
		
		main_window.show_all();
		main_window.present();
		show_welcome_window();
		release();
	}
	
	public void activate_nuvola_player()
	{
		hold();
		if (main_window == null)
			create_main_window();
			
		main_window.title = "Services - " + app_name;
		main_window.category = "AudioVideo";
		main_window.show_all();
		main_window.present();
		show_welcome_window();
		release();
	}
	
	public void activate_nuvola_apps()
	{
		hold();
		if (main_window == null)
			create_main_window();
			
		main_window.title = "Select a web app - Nuvola Apps Alpha";
		main_window.category = null;
		main_window.show_all();
		main_window.present();
		show_welcome_window();
		release();
	}
	
	public signal void runner_exited(AppRunner runner);
	
	private void init_core()
	{
		if (init_state >= InitState.CORE)
			return;
		
		/*
		 * Workaround for a GPU-related WebKit issue
		 * https://github.com/tiliado/nuvolaplayer/issues/24
		 */
		Environment.set_variable("LIBGL_DRI3_DISABLE", "1", true);
		
		app_runners = new Queue<AppRunner>();
		app_runners_map = new HashTable<string, AppRunner>(str_hash, str_equal);
		var default_config = new HashTable<string, Variant>(str_hash, str_equal);
		config = new Config(storage.user_config_dir.get_child("master").get_child("config.json"), default_config);
		
		var server_name = build_master_ipc_id();
		Environment.set_variable("NUVOLA_IPC_MASTER", server_name, true);
		try
		{
			server = new MasterBus(server_name);
			server.add_handler("runner_started", "(ss)", handle_runner_started);
			server.add_handler("runner_activated", "s", handle_runner_activated);
			server.api.add_method("/nuvola/core/get_top_runner", Drt.ApiFlags.READABLE, null, handle_get_top_runner, null);
			server.api.add_method("/nuvola/core/list_apps", Drt.ApiFlags.READABLE,
				"Returns information about all installed web apps.",
				handle_list_apps,  null);
			server.api.add_method("/nuvola/core/get_app_info", Drt.ApiFlags.READABLE,
				"Returns information about a web app",
				handle_get_app_info, {
				new Drt.StringParam("id", true, false, null, "Application id"),
				});
			server.start();
		}
		catch (Diorite.IOError e)
		{
			warning("Master server error: %s", e.message);
			quit();
			return;
		}
		
		storage_server = new Diorite.KeyValueStorageServer(server);
		storage_server.add_provider("master.config", config);
		
		var key_grabber = new XKeyGrabber();
		var key_binder = new GlobalActionsKeyBinder(key_grabber, config);
		actions_key_binder = new ActionsKeyBinderServer(server, key_binder, app_runners);
		media_keys = new MediaKeysServer(new MediaKeys(this.app_id, key_grabber), server, app_runners);
		
		#if EXPERIMENTAL
		var www_root_dirname = "www";
		File[] www_roots = {storage.user_data_dir.get_child(www_root_dirname)};
		foreach (var data_dir in storage.data_dirs)
			www_roots += data_dir.get_child(www_root_dirname);
		http_remote_control = new HttpRemoteControl.Server(
			this, server, app_runners_map, app_runners, web_app_reg, www_roots);
		#endif
		init_state = InitState.CORE;
	}
	
	private void init_gui()
	{
		init_core();
		if (init_state >= InitState.GUI)
			return;
		
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.SimpleAction("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
		new Diorite.SimpleAction("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
		new Diorite.SimpleAction("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		new Diorite.SimpleAction("main", "app", Actions.CREATE_LAUNCHERS, "Create application launchers", null, null, null, do_create_launchers),
		new Diorite.SimpleAction("main", "app", Actions.DELETE_LAUNCHERS, "Delete application launchers", null, null, null, do_delete_launchers),
		new Diorite.SimpleAction("main", "win", Actions.START_APP, "Start app", "_Start app", "media-playback-start", "<ctrl>S", do_start_app),
		new Diorite.SimpleAction("main", "win", Actions.INSTALL_APP, "Install app", "_Install app", "list-add", "<ctrl>plus", do_install_app),
		new Diorite.SimpleAction("main", "win", Actions.REMOVE_APP, "Remove app", "_Remove app", "list-remove", "<ctrl>minus", do_remove_app)
		};
		actions.add_actions(actions_spec);
		
		// TODO: actions.get_action(Actions.INSTALL_APP).enabled = web_app_reg.allow_management;
		
		set_app_menu(actions.build_menu({Actions.CREATE_LAUNCHERS, Actions.DELETE_LAUNCHERS, "|", Actions.HELP,Actions.ABOUT, Actions.QUIT}, true, false));
		
		if (Gtk.Settings.get_default().gtk_shell_shows_menubar)
		{
			/* For Unity */
			var menu = new Menu();
			menu.append_submenu("_Apps", actions.build_menu({Actions.START_APP, "|", Actions.INSTALL_APP, Actions.REMOVE_APP}));
			set_menubar(menu);
		}
		init_state = InitState.GUI;
	}
	
	private void create_main_window()
	{
		init_gui();
		var model = new WebAppListFilter(new WebAppListModel(web_app_reg), debuging, null);
		main_window = new WebAppListWindow(this, model);
		main_window.delete_event.connect(on_main_window_delete_event);
		main_window.view.item_activated.connect_after(on_list_item_activated);
	}
	
	private void show_welcome_window()
	{
		if (config.get_string("nuvola.welcome_screen") != get_welcome_screen_name())
		{
			var app_storage = new WebAppStorage(storage.user_config_dir, storage.user_data_dir, storage.user_cache_dir);
			WebEngine.init_web_context(app_storage);
			var welcome_window = new WelcomeWindow(this, storage);
			welcome_window.present();
			config.set_string("nuvola.welcome_screen", get_welcome_screen_name());
		}
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
		OptionEntry[] options = new OptionEntry[2];
		options[0] = { "app-id", 'a', 0, OptionArg.STRING, ref app_id, "Web app to run.", "ID" };
		options[1] = { null };
		
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
			_args.length = tmp.length;
		}
		catch (OptionError e)
		{
			command_line.print("option parsing failed: %s\n", e.message);
			return 1;
		}
		
		var nuvola_apps = false;
		foreach (var arg in _args)
		{
			if (arg == "__nuvola_apps__")
			{
				nuvola_apps = true;
				break;
			}
		}
		
		if (_args.length > (nuvola_apps ? 2 : 1))
		{
			stderr.printf("Too many arguments.\n");
			return 1;
		}
		
		init_core();
		if (app_id != null)
			start_app(app_id);
		else if (nuvola_apps)
			activate_nuvola_apps();
		else
			activate_nuvola_player();
		
		return 0;
	}
	
	private Variant? handle_runner_started(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		string? app_id = null;
		string? server_name = null;
		data.get("(ss)", ref app_id, ref server_name);
		return_val_if_fail(app_id != null && server_name != null, null);
		
		var runner = app_runners_map[app_id];
		return_val_if_fail(runner != null, null);
		
		var channel = source as Drt.ApiChannel;
		if (channel == null)
			throw new Diorite.MessageError.REMOTE_ERROR("Failed to connect runner '%s'. %s ", app_id, source.get_type().name());
		runner.connect_channel(channel);
		debug("Connected to runner server for '%s'.", app_id);
		return new Variant.boolean(true);
	}
	
	private Variant? handle_runner_activated(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var app_id = data.get_string();
		return_val_if_fail(app_id != null, null);
		
		var runner = app_runners_map[app_id];
		return_val_if_fail(runner != null, null);
		
		if (!app_runners.remove(runner))
			critical("Runner for '%s' not found in queue.", runner.app_id);
		
		app_runners.push_head(runner);
		return new Variant.boolean(true);
	}
	
	private Variant? handle_get_top_runner(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var runner = app_runners.peek_head();
		return new Variant("ms", runner == null ? null : runner.app_id);
	}
	
	private Variant? handle_list_apps(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var builder = new VariantBuilder(new VariantType("aa{sv}"));
		var dict_type = new VariantType("a{sv}");
		var all_apps = web_app_reg.list_web_apps();
		var keys = all_apps.get_keys();
		keys.sort(string.collate);
		foreach (var app_id in keys)
		{
			var app = all_apps[app_id];
			builder.open(dict_type);
			builder.add("{sv}", "id", new Variant.string(app_id));
			builder.add("{sv}", "name", new Variant.string(app.name));
			builder.add("{sv}", "version", new Variant.string("%u.%u".printf(app.version_major, app.version_minor)));
			builder.add("{sv}", "maintainer", new Variant.string(app.maintainer_name));
			var app_runner = app_runners_map[app_id];
			builder.add("{sv}", "running", new Variant.boolean(app_runner != null));
			var capatibilities_array = new VariantBuilder(new VariantType("as"));
			if (app_runner != null)
			{
				var capatibilities = app_runner.get_capatibilities();
				foreach (var capability in capatibilities)
					capatibilities_array.add("s", capability);
			}
			builder.add("{sv}", "capabilities", capatibilities_array.end());
			builder.close();
		}
		return builder.end();
	}
	
	private Variant? handle_get_app_info(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var app_id = params.pop_string();
		var app = web_app_reg.get_app_meta(app_id);
		if (app == null)
			return null;
			
		var builder = new VariantBuilder(new VariantType("a{sv}"));
		builder.add("{sv}", "id", new Variant.string(app_id));
		builder.add("{sv}", "name", new Variant.string(app.name));
		builder.add("{sv}", "version", new Variant.string("%u.%u".printf(app.version_major, app.version_minor)));
		builder.add("{sv}", "maintainer", new Variant.string(app.maintainer_name));
		var app_runner = app_runners_map[app_id];
		builder.add("{sv}", "running", new Variant.boolean(app_runner != null));
		var capatibilities_array = new VariantBuilder(new VariantType("as"));
		if (app_runner != null)
		{
			var capatibilities = app_runner.get_capatibilities();
			foreach (var capability in capatibilities)
				capatibilities_array.add("s", capability);
		}
		builder.add("{sv}", "capabilities", capatibilities_array.end());
		return builder.end();
	}
	
	private bool on_main_window_delete_event(Gdk.EventAny event)
	{
		do_quit();
		return true;
	}
	
	private void do_quit()
	{
		main_window.hide();
		remove_window(main_window);
		main_window.destroy();
		main_window = null;
	}
	
	private void do_install_app()
	{
		show_uri("https://github.com/tiliado/nuvolaplayer/wiki/Web-App-Scripts");
		#if FALSE
		// TODO: create web app script tarballs or remove this code
		var dialog = new Gtk.FileChooserDialog(("Choose service integration package"),
			main_window, Gtk.FileChooserAction.OPEN, "Cancel",
			Gtk.ResponseType.CANCEL, "Open", Gtk.ResponseType.ACCEPT
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
				var info = new Diorite.InfoDialog(("Installation successfull"),
					("Service %1$s (version %2$d.%3$d) has been installed succesfuly").printf(
					app.name, app.version_major, app.version_minor));
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
		#endif
	}
	
	private void do_remove_app()
	{
		if (main_window.selected_web_app == null)
			return;
		
		var web_app = web_app_reg.get_app_meta(main_window.selected_web_app);
		if (web_app == null)
			return;
		try
		{
			web_app_reg.remove_app(web_app);
			var info = new Diorite.InfoDialog(("Removal successfull"),
				("Service %1$s (version %2$d.%3$d) has been succesfuly removed").printf(web_app.name, web_app.version_major, web_app.version_minor));
			info.run();
		}
		catch (WebAppError e)
		{
			var error = new Diorite.ErrorDialog(("Removal failed"),
				_("Removal of service %s failed.").printf(web_app.name)
				+ "\n\n" + e.message);
			error.run();
		}
	}
	
	private void on_list_item_activated(Gtk.TreePath path)
	{
		do_start_app();
	}
	
	private void do_about()
	{
		var dialog = new AboutDialog(main_window, null);
		dialog.run();
		dialog.destroy();
	}
	
	private void do_help()
	{
		show_uri(Nuvola.HELP_URL);
	}
	
	private void do_start_app()
	{
		if (main_window.selected_web_app == null)
			return;
		
		main_window.hide();
		start_app(main_window.selected_web_app);
		do_quit();
	}
	
	private void do_create_launchers()
	{
		create_desktop_files.begin(web_app_reg, false, (o, res) =>
		{
			create_desktop_files.end(res);
			 if (main_window != null)
				main_window.info_bars.create_info_bar("Application launchers have been created.");
		});
	}
	
	private void do_delete_launchers()
	{
		var whitelist = new GenericSet<string>(str_hash, str_equal, null);
		app_runners_map.foreach ((key, val) => { whitelist.add(get_desktop_file_name(key)); });
		delete_desktop_files.begin(whitelist, (o, res) =>
		{
			delete_desktop_files.end(res);
			if (main_window != null)
				main_window.info_bars.create_info_bar("Application launchers have been deleted.");
		});
	}
	
	private void start_app(string app_id)
	{
		hold();
		
		var app_meta = web_app_reg.get_app_meta(app_id);
		if (app_meta == null)
		{
			var dialog = new Diorite.ErrorDialog(
				"Web App Loading Error",
				"The web application with id '%s' has not been found.".printf(app_id));
			dialog.run();
			dialog.destroy();
			release();
			return;
		}
		
		string[] argv = new string[exec_cmd.length + 3];
		for (var i = 0; i < exec_cmd.length; i++)
			argv[i] = exec_cmd[i];
		
		var j = exec_cmd.length;
		argv[j++] = "-a";
		argv[j++] = app_meta.data_dir.get_path();
		argv[j++] = null;
		
		AppRunner runner;
		debug("Launch app runner for '%s': %s", app_id, string.joinv(" ", argv));
		try
		{
			runner = new AppRunner(app_id, argv);
		}
		catch (GLib.Error e)
		{
			warning("Failed to launch app runner for '%s'. %s", app_id, e.message);
			var dialog = new Diorite.ErrorDialog(
				"Web App Loading Error",
				"The web application '%s' has failed to load.".printf(app_meta.name));
			dialog.run();
			dialog.destroy();
			release();
			return;
		}
		
		runner.exited.connect(on_runner_exited);
		app_runners.push_tail(runner);
		
		if (app_id in app_runners_map)
			debug("App runner for '%s' is already running.", app_id);
		else
			app_runners_map[app_id] = runner;
		
		show_welcome_window();
	}
	
	private void on_runner_exited(AppRunner runner)
	{
		debug("Runner exited: %s, was connected: %s", runner.app_id, runner.connected.to_string());
		runner.exited.disconnect(on_runner_exited);
		if (!app_runners.remove(runner))
			critical("Runner for '%s' not found in queue.", runner.app_id);
		
		if (app_runners_map[runner.app_id] == runner)
			app_runners_map.remove(runner.app_id);
		
		runner_exited(runner);
		release();
	}
	
	private enum InitState
	{
		NONE,
		CORE,
		GUI;
	}
}

} // namespace Nuvola
