/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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
	public const string QUIT = "quit";
}

public string build_master_ipc_id()
{
	return "N3";
}

public class MasterController : Diorite.Application
{
	private const string APP_STARTED = "/nuvola/core/app-started";
	private const string APP_EXITED = "/nuvola/core/app-exited";
	private const string TILIADO_ACCOUNT_TOKEN_TYPE = "tiliado.account2.token_type";
	private const string TILIADO_ACCOUNT_ACCESS_TOKEN = "tiliado.account2.access_token";
	private const string TILIADO_ACCOUNT_REFRESH_TOKEN = "tiliado.account2.refresh_token";
	private const string TILIADO_ACCOUNT_SCOPE = "tiliado.account2.scope";
	private const string TILIADO_ACCOUNT_MEMBERSHIP = "tiliado.account2.membership";
	private const string TILIADO_ACCOUNT_USER = "tiliado.account2.user";
	private const string TILIADO_ACCOUNT_EXPIRES = "tiliado.account2.expires";
	private const string TILIADO_ACCOUNT_SIGNATURE = "tiliado.account2.signature";
	private const string PAGE_WELCOME = "welcome";
	
	public MasterWindow? main_window {get; private set; default = null;}
	public WebAppList? web_app_list {get; private set; default = null;}
	public Diorite.Storage storage {get; private set; default = null;}
	public WebAppRegistry? web_app_reg {get; private set; default = null;}
	public Config config {get; private set; default = null;}
	private string[] exec_cmd;
	private Queue<AppRunner> app_runners = null;
	private HashTable<string, AppRunner> app_runners_map = null;
	private MasterBus server = null;
	private DbusApi? dbus_api = null;
	private uint dbus_api_id = 0;
	
	private Diorite.KeyValueStorageServer storage_server = null;
	private ActionsKeyBinderServer actions_key_binder = null;
	private MediaKeysServer media_keys = null;
	#if TILIADO_API
	private TiliadoApi2? tiliado = null;
	private TiliadoAccountWidget? tiliado_widget = null;
	#endif
	private string? start_app_after_activation = null;
	#if EXPERIMENTAL
	private HttpRemoteControl.Server http_remote_control = null;
	#endif
	private InitState init_state = InitState.NONE;
	private bool debuging;
	
	public MasterController(Diorite.Storage storage, WebAppRegistry? web_app_reg, string[] exec_cmd, bool debuging=false)
	{
		base(Nuvola.get_app_uid(), Nuvola.get_app_name(), Nuvola.get_dbus_id(), ApplicationFlags.HANDLES_COMMAND_LINE);
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
		show_main_window();
		show_welcome_screen();
		#if FLATPAK
		if (!is_desktop_portal_available())
			quit();
		#endif
		release();
	}
	
	public void show_main_window(string? page=null)
	{
		if (main_window == null)
			create_main_window();
		main_window.present();
		if (page != null)
			main_window.stack.visible_child_name = page;
	}
	
	public signal void runner_exited(AppRunner runner);
	
	public override bool dbus_register(DBusConnection conn, string object_path)
		throws GLib.Error
	{
		if (!base.dbus_register(conn, object_path))
			return false;
		init_core();
		dbus_api = new DbusApi(this);
		dbus_api_id = conn.register_object(object_path, dbus_api);
		return true;
	}
	
	public override void dbus_unregister(DBusConnection conn, string object_path)
	{
		if (dbus_api_id > 0)
		{
			conn.unregister_object(dbus_api_id);
			dbus_api_id = 0;
		}
		base.dbus_unregister(conn, object_path);
	}
	
	#if FLATPAK
	private bool is_desktop_portal_available()
	{
		
		try
		{
			Flatpak.check_desktop_portal_available(null);
			return true;
		}
		catch (GLib.Error e)
		{
			var dialog = new Gtk.MessageDialog.with_markup(
				main_window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
				("<b><big>Failed to connect to XDG Desktop Portal</big></b>\n\n"
				+ "Make sure the XDG Desktop Portal is installed on your system. "
				+ "It might be sufficient to install the xdg-desktop-portal and xdg-desktop-portal-gtk "
				+ "packages. If unsure, follow detailed installation instructions at https://nuvola.tiliado.eu"
				+ "\n\n%s"), e.message);
			Timeout.add_seconds(60, () => { dialog.destroy(); return false;});
			dialog.run();
			return false;
		}
	}
	#endif
	
	private void init_core()
	{
		if (init_state >= InitState.CORE)
			return;
		
		app_runners = new Queue<AppRunner>();
		app_runners_map = new HashTable<string, AppRunner>(str_hash, str_equal);
		var default_config = new HashTable<string, Variant>(str_hash, str_equal);
		config = new Config(storage.user_config_dir.get_child("master").get_child("config.json"), default_config);
		
		#if TILIADO_API
		init_tiliado_account();
		#endif
		
		var server_name = build_master_ipc_id();
		Environment.set_variable("NUVOLA_IPC_MASTER", server_name, true);
		try
		{
			server = new MasterBus(server_name);
			server.api.add_method("/nuvola/core/runner-started", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
				null,
				handle_runner_started, {
				new Drt.StringParam("id", true, false, null, "Application id"),
				new Drt.StringParam("token", true, false, null, "Application token"),
				});
			server.api.add_method("/nuvola/core/runner-activated", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
				null,
				handle_runner_activated, {
				new Drt.StringParam("id", true, false, null, "Application id"),
				});
			server.api.add_method("/nuvola/core/get_top_runner", Drt.ApiFlags.READABLE, null, handle_get_top_runner, null);
			server.api.add_method("/nuvola/core/list_apps", Drt.ApiFlags.READABLE,
				"Returns information about all installed web apps.",
				handle_list_apps,  null);
			server.api.add_method("/nuvola/core/get_app_info", Drt.ApiFlags.READABLE,
				"Returns information about a web app",
				handle_get_app_info, {
				new Drt.StringParam("id", true, false, null, "Application id"),
				});
			server.api.add_notification(APP_STARTED, Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE,
				"Emitted when a new app is launched.");
			server.api.add_notification(APP_EXITED, Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE,
				"Emitted when a app has exited.");
			server.start();
		}
		catch (Diorite.IOError e)
		{
			warning("Master server error: %s", e.message);
			quit();
			return;
		}
		
		storage_server = new Diorite.KeyValueStorageServer(server.api);
		storage_server.add_provider("master.config", config);
		
		var key_grabber = new XKeyGrabber();
		var key_binder = new GlobalActionsKeyBinder(key_grabber, config);
		actions_key_binder = new ActionsKeyBinderServer(server, key_binder, app_runners);
		media_keys = new MediaKeysServer(new MediaKeys(this.app_id, key_grabber), server, app_runners);
		
		#if EXPERIMENTAL
		storage.assert_data_file("www/engine.io.js");
		var www_root_dirname = "www";
		File[] www_roots = {storage.user_data_dir.get_child(www_root_dirname)};
		foreach (var data_dir in storage.data_dirs)
			www_roots += data_dir.get_child(www_root_dirname);
		http_remote_control = new HttpRemoteControl.Server(
			this, server, app_runners_map, app_runners, www_roots);
		#endif
		init_state = InitState.CORE;
	}
	
	private void init_gui()
	{
		init_core();
		if (init_state >= InitState.GUI)
			return;
		
		#if FLATPAK
		Graphics.ensure_gl_extension_mounted(main_window);
		#endif
		
		Diorite.Action[] actions_spec = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.SimpleAction("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
		new Diorite.SimpleAction("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
		new Diorite.SimpleAction("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
		new Diorite.SimpleAction("main", "win", Actions.START_APP, "Start app", "_Start app", "media-playback-start", "<ctrl>S", do_start_app),
		};
		actions.add_actions(actions_spec);
		
		set_app_menu_items({Actions.HELP, Actions.ABOUT, Actions.QUIT});
		
		var app_storage = new WebAppStorage(storage.user_config_dir, storage.user_data_dir, storage.user_cache_dir);
		WebEngine.init_web_context(app_storage);
		init_state = InitState.GUI;
	}
	
	private void create_main_window()
	{
		init_gui();
		main_window = new MasterWindow(this);
		main_window.page_changed.connect(on_master_stack_page_changed);
		var welcome_screen = new WelcomeScreen(this, storage);
		welcome_screen.show();
		main_window.add_page(welcome_screen, PAGE_WELCOME, "Welcome");
		#if FLATPAK && !NUVOLA_ADK
		var app_index_view = new AppIndexWebView(this, WebEngine.get_web_context());
		app_index_view.load_app_index(Nuvola.REPOSITORY_INDEX, Nuvola.REPOSITORY_ROOT);
		app_index_view.show();
		main_window.add_page(app_index_view, "repository", "Repository Index");
		#endif
		
		if (web_app_reg != null)
		{
			var model = new WebAppListFilter(new WebAppListModel(web_app_reg), debuging, null);
			web_app_list = new WebAppList(this, model);
			main_window.delete_event.connect(on_main_window_delete_event);
			web_app_list.view.item_activated.connect_after(on_list_item_activated);
			web_app_list.show();
			main_window.add_page(web_app_list, "scripts", "Installed Apps");
		}
		
		#if TILIADO_API
		string? user_name = null;
		int membership = -1;
		if (is_tiliado_account_valid(0))
		{
			user_name = config.get_string(TILIADO_ACCOUNT_USER);
			membership = (int) config.get_int64(TILIADO_ACCOUNT_MEMBERSHIP);
		}
		tiliado_widget = new TiliadoAccountWidget(tiliado, this, Gtk.Orientation.HORIZONTAL, user_name, membership);
		main_window.top_grid.insert_row(1);
		if (tiliado_widget.full_width)
			main_window.top_grid.attach(tiliado_widget, 0, 1, 1, 1);
		else
			main_window.header_bar.pack_end(tiliado_widget);
		tiliado_widget.show();
		tiliado_widget.notify["full-width"].connect_after(on_tiliado_widget_full_width_changed);
		#endif
	}
	
	private void show_welcome_screen()
	{
		if (config.get_string("nuvola.welcome_screen") != get_welcome_screen_name())
		{
			show_main_window(PAGE_WELCOME);
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
		bool list_apps = false;
		bool list_apps_json = false;
		OptionEntry[] options = new OptionEntry[4];
		options[0] = { "app-id", 'a', 0, OptionArg.STRING, ref app_id, "Web app to run.", "ID" };
		options[1] = { "list-apps", 'l', 0, OptionArg.NONE, ref list_apps, "List available application.", null };
		options[2] = { "list-apps-json", 'j', 0, OptionArg.NONE, ref list_apps_json, "List available application (JSON output).", null };
		options[3] = { null };
		
		// We have to make an extra copy of the array, since .parse assumes
		// that it can remove strings from the array without freeing them.
		string[] args = command_line.get_arguments();
		string*[] _args = new string[args.length];
		for (int i = 0; i < args.length; i++)
			_args[i] = args[i];
		
		try
		{
			var opt_context = new OptionContext("- " + Nuvola.get_app_name());
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			unowned string[] tmp = _args;
			opt_context.parse(ref tmp);
			_args.length = tmp.length;
		}
		catch (OptionError e)
		{
			command_line.printerr("option parsing failed: %s\n", e.message);
			return 1;
		}
		
		if (_args.length >  1)
		{
			command_line.printerr("%s", "Too many arguments.\n");
			return 1;
		}
		
		init_core();
		
		if (list_apps || list_apps_json)
		{
			var all_apps = web_app_reg.list_web_apps(null);
			var keys = all_apps.get_keys();
			keys.sort(strcmp);
			
			if (list_apps_json)
			{
				var builder = new Drt.JsonBuilder();
				builder.begin_array();
				foreach (var key in keys)
				{
					builder.begin_object();
					builder.set_string("id", key);
					var app = all_apps[key];
					builder.set_string("name", app.name);
					builder.set_printf("version", "%d.%d", app.version_major, app.version_minor);
					builder.set_member("datadir");
					if (app.data_dir == null)
						builder.add_null();
					else
						builder.add_string(app.data_dir.get_path());
					builder.end_object();
				}
				builder.end_array();
				command_line.print_literal(builder.to_pretty_string());
			}
			else
			{
				var buf = new StringBuilder();
				foreach (var key in keys)
				{
					var app = all_apps[key];
					string path = app.data_dir == null ? "" : app.data_dir.get_path();
					buf.append_printf("%s | %s | %d.%d | %s\n",
						key, app.name, app.version_major, app.version_minor, path);
				}
				command_line.print_literal(buf.str);
			}
			return 0;
		}
		if (app_id != null)
			start_app(app_id);
		else
			activate();
		return 0;
	}
	
	private Variant? handle_runner_started(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var app_id = params.pop_string();
		var api_token = params.pop_string();
		var runner = app_runners_map[app_id];
		return_val_if_fail(runner != null, null);
		
		var channel = source as Drt.ApiChannel;
		if (channel == null)
			throw new Diorite.MessageError.REMOTE_ERROR("Failed to connect runner '%s'. %s ", app_id, source.get_type().name());
		channel.api_token = api_token;
		runner.connect_channel(channel);
		debug("Connected to runner server for '%s'.", app_id);
		server.api.emit(APP_STARTED, app_id, app_id);
		return new Variant.boolean(true);
	}
	
	private Variant? handle_runner_activated(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var app_id = params.pop_string();
		var runner = app_runners_map[app_id];
		return_val_if_fail(runner != null, false);
		
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
		var keys = app_runners_map.get_keys();
		keys.sort(string.collate);
		foreach (var app_id in keys)
			builder.add_value(app_runners_map[app_id].query_meta());
		return builder.end();
	}
	
	private Variant? handle_get_app_info(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var app_id = params.pop_string();
		var app = app_runners_map[app_id];
		return app != null ? app.query_meta() : null;
	}
	
	private void on_master_stack_page_changed(Gtk.Widget? page, string? name, string? title)
	{
		if (page != null && page == web_app_list)
		{
			set_toolbar({Actions.START_APP});
			reset_menubar().append_submenu("_Apps", actions.build_menu({Actions.START_APP})); // For Unity
		}
		else
		{
			set_toolbar({});
			reset_menubar();
		}
	}
	
	private void set_toolbar(string[] items)
	{
		main_window.create_toolbar(items);
		#if TILIADO_API
		if (tiliado_widget != null && !tiliado_widget.full_width)
			main_window.header_bar.pack_end(tiliado_widget);
		#endif
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
		if (web_app_list.selected_web_app == null)
			return;
		if (is_tiliado_account_valid(TiliadoMembership.PREMIUM))
		{
			main_window.hide();
			start_app(web_app_list.selected_web_app);
			do_quit();
		}
		else
		{
			start_app_after_activation = web_app_list.selected_web_app;
		}
	}
	
	private void start_app(string app_id)
	{
		hold();
		#if FLATPAK
		if (!is_desktop_portal_available())
		{
			release();
			quit();
			return;
		}
		#endif
	
		if (!is_tiliado_account_valid(TiliadoMembership.PREMIUM))
		{
			start_app_after_activation = app_id;
			activate();
			release();
			return;
		}
		#if FLATPAK && NUVOLA_RUNTIME
		try
		{
			var uid = build_camel_id(app_id);
			var path = "/" + uid.replace(".", "/");
			var app_api = Bus.get_proxy_sync<AppDbusIfce>(
				BusType.SESSION, uid, path,
				DBusProxyFlags.DO_NOT_CONNECT_SIGNALS|DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
			app_api.activate();
			debug("DBus activation of %s succeeded.", uid);
			show_welcome_screen();
			Timeout.add_seconds(5, () => {release(); return false;});
		}
		catch (GLib.Error e)
		{
			warning("DBus Activation error: %s", e.message);
			var dialog = new Diorite.ErrorDialog(
				"Web App Loading Error",
				("The web application with id '%s' has not been found.\n\n"
				+ "DBus Activation has ended with an error:\n%s").printf(app_id, e.message));
			dialog.run();
			dialog.destroy();
			release();
		}
		#else		
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
			runner = new SubprocessAppRunner(app_id, argv, server.router.hex_token);
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
		show_welcome_screen();
		#endif
	}
	
	public bool start_app_from_dbus(string app_id, string dbus_id, out string token)
	{
		token = null;
		#if FLATPAK
		if (!is_desktop_portal_available())
		{
			quit();
			return false;
		}
		#endif
	
		if (!is_tiliado_account_valid(TiliadoMembership.PREMIUM))
		{
			activate();
			return false;
		}
		
		hold();
		AppRunner runner;
		token = null;
		debug("Launch app runner for '%s': %s", app_id, dbus_id);
		try
		{
			runner = new DbusAppRunner(app_id, dbus_id, server.router.hex_token);
			token = server.router.hex_token;
		}
		catch (GLib.Error e)
		{
			warning("Failed to launch app runner for '%s'. %s", app_id, e.message);
			var dialog = new Diorite.ErrorDialog(
				"Web App Loading Error",
				"The web application '%s' has failed to load.".printf(dbus_id));
			dialog.run();
			dialog.destroy();
			release();
			return false;
		}
		
		runner.exited.connect(on_runner_exited);
		app_runners.push_tail(runner);
		
		if (app_id in app_runners_map)
			debug("App runner for '%s' is already running.", app_id);
		else
			app_runners_map[app_id] = runner;
		
		show_welcome_screen();
		return true;
	}
	
	private void on_runner_exited(AppRunner runner)
	{
		debug("Runner exited: %s, was connected: %s", runner.app_id, runner.connected.to_string());
		runner.exited.disconnect(on_runner_exited);
		if (!app_runners.remove(runner))
			critical("Runner for '%s' not found in queue.", runner.app_id);
		
		if (app_runners_map[runner.app_id] == runner)
			app_runners_map.remove(runner.app_id);
		
		server.api.emit(APP_EXITED, runner.app_id, runner.app_id);
		runner_exited(runner);
		release();
	}
	
	#if !TILIADO_API
	public bool is_tiliado_account_valid(TiliadoMembership required_membership)
	{
		return true;
	}
	#endif
	
	#if TILIADO_API
	private void init_tiliado_account()	
	{
		assert(TILIADO_OAUTH2_CLIENT_ID != null && TILIADO_OAUTH2_CLIENT_ID[0] != '\0');
		Oauth2Token token = null;
		if (config.has_key(TILIADO_ACCOUNT_ACCESS_TOKEN))
			token = new Oauth2Token(
				config.get_string(TILIADO_ACCOUNT_ACCESS_TOKEN),
				config.get_string(TILIADO_ACCOUNT_REFRESH_TOKEN),
				config.get_string(TILIADO_ACCOUNT_TOKEN_TYPE),
				config.get_string(TILIADO_ACCOUNT_SCOPE));
		tiliado = new TiliadoApi2(
			TILIADO_OAUTH2_CLIENT_ID, Diorite.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data),
			TILIADO_OAUTH2_API_ENDPOINT, TILIADO_OAUTH2_TOKEN_ENDPOINT, token, "nuvolaplayer");
		tiliado.notify["token"].connect_after(on_tiliado_api_token_changed);
		tiliado.notify["user"].connect_after(on_tiliado_api_user_changed);
	}
	
	public bool is_tiliado_account_valid(TiliadoMembership required_membership)
	{	
		var signature = config.get_string(TILIADO_ACCOUNT_SIGNATURE);
		if (signature == null)
		{
			unset_tiliado_user_info();
			return false;
		}
		var expires = config.get_int64(TILIADO_ACCOUNT_EXPIRES);
		var user_name = config.get_string(TILIADO_ACCOUNT_USER);
		var	membership = (uint) config.get_int64(TILIADO_ACCOUNT_MEMBERSHIP);
		if (!tiliado.hmac_sha1_verify_string(concat_tiliado_user_info(user_name, membership, expires), signature))
		{
			unset_tiliado_user_info();
			return false;
		}
		
		return new DateTime.now_utc().to_unix() <= expires && membership >= required_membership;			
	}
	
	private void on_tiliado_api_token_changed(GLib.Object o, ParamSpec p)
	{
		var token = tiliado.token;
		if (token != null)
		{
			config.set_value(TILIADO_ACCOUNT_TOKEN_TYPE, token.token_type);
			config.set_value(TILIADO_ACCOUNT_ACCESS_TOKEN, token.access_token);
			config.set_value(TILIADO_ACCOUNT_REFRESH_TOKEN, token.refresh_token);
			config.set_value(TILIADO_ACCOUNT_SCOPE, token.scope);
		}
		else
		{
			config.unset(TILIADO_ACCOUNT_TOKEN_TYPE);
			config.unset(TILIADO_ACCOUNT_ACCESS_TOKEN);
			config.unset(TILIADO_ACCOUNT_REFRESH_TOKEN);
			config.unset(TILIADO_ACCOUNT_SCOPE);
			unset_tiliado_user_info();
		}
	}
	
	private void on_tiliado_api_user_changed(GLib.Object o, ParamSpec p)
	{
		var user = tiliado.user;
		if (user != null)
		{
			var expires = new DateTime.now_utc().add_weeks(2).to_unix();
			set_tiliado_user_info(user.name, user.membership, expires);
			if (start_app_after_activation != null && is_tiliado_account_valid(TiliadoMembership.PREMIUM))
			{
				if (main_window != null)
				{
					main_window.hide();
					do_quit();
				}
				start_app(start_app_after_activation);
				start_app_after_activation = null;
			}
		}
		else
		{
			unset_tiliado_user_info();
		}
	}
	
	private void set_tiliado_user_info(string name, uint membership_rank, int64 expires)
	{
		config.set_string(TILIADO_ACCOUNT_USER, name);
		config.set_int64(TILIADO_ACCOUNT_MEMBERSHIP, (int64) membership_rank);
		config.set_int64(TILIADO_ACCOUNT_EXPIRES, expires);
		var signature = tiliado.hmac_sha1_for_string(concat_tiliado_user_info(name, membership_rank, expires));
		config.set_string(TILIADO_ACCOUNT_SIGNATURE, signature);	
	}
	
	private inline string concat_tiliado_user_info(string name, uint membership_rank, int64 expires)
	{
		return "%s:%u:%s".printf(name, membership_rank, expires.to_string());
	}
	
	private void unset_tiliado_user_info()
	{
		config.unset(TILIADO_ACCOUNT_USER);
		config.unset(TILIADO_ACCOUNT_MEMBERSHIP);
		config.unset(TILIADO_ACCOUNT_EXPIRES);
		config.unset(TILIADO_ACCOUNT_SIGNATURE);
	}
	
	private void on_tiliado_widget_full_width_changed(GLib.Object emitter, ParamSpec p)
	{
		var tiliado_widget = emitter as TiliadoAccountWidget;
		var parent = tiliado_widget.get_parent();
		if (parent != null)
			parent.remove(tiliado_widget);
		if (tiliado_widget.full_width)
			main_window.top_grid.attach(tiliado_widget, 0, 1, 1, 1);
		else
			main_window.header_bar.pack_end(tiliado_widget);
	}
	#endif
	
	private enum InitState
	{
		NONE,
		CORE,
		GUI;
	}
}


[DBus(name="eu.tiliado.Nuvola")]
public class DbusApi: GLib.Object
{
	private unowned MasterController controller;
	
	public DbusApi(MasterController controller)
	{
		this.controller = controller;
	}
	
	public void get_connection(string app_id, string dbus_id, out Socket? socket, out string? token) throws GLib.Error
	{
		if (controller.start_app_from_dbus(app_id, dbus_id, out token))
			socket = Diorite.SocketChannel.create_socket_from_name(build_master_ipc_id()).socket;
		else
			throw new Diorite.Error.ACCESS_DENIED("Nuvola refused connection.");
	}
}


[DBus(name="eu.tiliado.NuvolaApp")]
public interface AppDbusIfce: GLib.Object
{
	public abstract void activate() throws GLib.Error;
}

} // namespace Nuvola
