/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

public string build_master_ipc_id() {
    return "N3";
}

public class MasterController : Drtgtk.Application {
    private const string APP_STARTED = "/nuvola/core/app-started";
    private const string APP_EXITED = "/nuvola/core/app-exited";

    public Drt.Storage storage {get; private set; default = null;}
    public WebAppRegistry? web_app_reg {get; private set; default = null;}
    public Config config {get; private set; default = null;}
    public TiliadoActivation? activation {get; private set; default = null;}
    public bool debuging {get; private set; default = false;}
    private string[] exec_cmd;
    private Queue<AppRunner> app_runners = null;
    private HashTable<string, AppRunner> app_runners_map = null;
    private MasterBus server = null;
    private MasterDbusApi? dbus_api = null;
    private uint dbus_api_id = 0;
    private MasterUserInterface? _ui = null;
    private Drt.KeyValueStorageServer storage_server = null;
    private ActionsKeyBinderServer actions_key_binder = null;
    private MediaKeysServer media_keys = null;

    #if EXPERIMENTAL
    private HttpRemoteControl.Server http_remote_control = null;
    #endif

    private bool initialized = false;

    public MasterController(Drt.Storage storage, WebAppRegistry? web_app_reg, string[] exec_cmd,
        bool debuging=false) {
        base(Nuvola.get_app_uid(), Nuvola.get_app_name(), Nuvola.get_dbus_id(),
            ApplicationFlags.HANDLES_COMMAND_LINE);
        icon = Nuvola.get_app_icon();
        version = Nuvola.get_version();
        this.storage = storage;
        this.web_app_reg = web_app_reg;
        this.exec_cmd = exec_cmd;
        this.debuging = debuging;
    }

    public signal void runner_exited(AppRunner runner);

    public override void activate() {
        hold();
        get_ui().show_main_window();
        release();
    }

    public override bool dbus_register(DBusConnection conn, string object_path) throws GLib.Error {
        if (!base.dbus_register(conn, object_path)) {
            return false;
        }
        dbus_api = new MasterDbusApi(this);
        dbus_api_id = conn.register_object(object_path, dbus_api);
        return true;
    }

    public override void dbus_unregister(DBusConnection conn, string object_path) {
        if (dbus_api_id > 0) {
            conn.unregister_object(dbus_api_id);
            dbus_api_id = 0;
        }
        base.dbus_unregister(conn, object_path);
    }

    public override void apply_custom_styles(Gdk.Screen screen) {
        base.apply_custom_styles(screen);
        Nuvola.Css.apply_custom_styles(screen);
    }

    public override int command_line(ApplicationCommandLine command_line) {
        hold();
        var result = handle_command_line(command_line);
        release();
        return result;
    }

    private int handle_command_line(ApplicationCommandLine command_line) {
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
        for (int i = 0; i < args.length; i++) {
            _args[i] = args[i];
        }
        try {
            var opt_context = new OptionContext("- " + Nuvola.get_app_name());
            opt_context.set_help_enabled(true);
            opt_context.add_main_entries(options, null);
            unowned string[] tmp = _args;
            opt_context.parse(ref tmp);
            _args.length = tmp.length;
        } catch (OptionError e) {
            command_line.printerr("option parsing failed: %s\n", e.message);
            return 1;
        }

        if (_args.length >  1) {
            command_line.printerr("%s", "Too many arguments.\n");
            return 1;
        }

        late_init();

        if (list_apps || list_apps_json) {
            var all_apps = web_app_reg.list_web_apps(null);
            var keys = all_apps.get_keys();
            keys.sort(strcmp);

            if (list_apps_json) {
                var builder = new Drt.JsonBuilder();
                builder.begin_array();
                foreach (var key in keys) {
                    builder.begin_object();
                    builder.set_string("id", key);
                    var app = all_apps[key];
                    builder.set_string("name", app.name);
                    builder.set_printf("version", "%d.%d", app.version_major, app.version_minor);
                    builder.set_member("datadir");
                    if (app.data_dir == null) {
                        builder.add_null();
                    } else {
                        builder.add_string(app.data_dir.get_path());
                    }
                    builder.end_object();
                }
                builder.end_array();
                command_line.print_literal(builder.to_pretty_string());
            } else {
                var buf = new StringBuilder();
                foreach (var key in keys) {
                    var app = all_apps[key];
                    string path = app.data_dir == null ? "" : app.data_dir.get_path();
                    buf.append_printf("%s | %s | %d.%d | %s\n",
                        key, app.name, app.version_major, app.version_minor, path);
                }
                command_line.print_literal(buf.str);
            }
            return 0;
        }
        if (app_id != null) {
            start_app.begin(app_id, (o, res) => start_app.end(res));
        } else {
            activate();
        }
        return 0;
    }

    public unowned MasterUserInterface get_ui() {
        if (_ui == null) {
            late_init();
            _ui = new MasterUserInterface(this);
        }
        return _ui;
    }

    private void late_init() {
        if (initialized) {
            return;
        }

        app_runners = new Queue<AppRunner>();
        app_runners_map = new HashTable<string, AppRunner>(str_hash, str_equal);
        var default_config = new HashTable<string, Variant>(str_hash, str_equal);
        config = new Config(storage.user_config_dir.get_child("master").get_child("config.json"), default_config);

        var server_name = build_master_ipc_id();
        Environment.set_variable("NUVOLA_IPC_MASTER", server_name, true);
        try {
            server = new MasterBus(server_name);
            server.api.add_method("/nuvola/core/runner-started", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
                null,
                handle_runner_started, {
                    new Drt.StringParam("id", true, false, null, "Application id"),
                    new Drt.StringParam("token", true, false, null, "Application token"),
                });
            server.api.add_method("/nuvola/core/runner-activated", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
                null,
                handle_runner_activated, {
                    new Drt.StringParam("id", true, false, null, "Application id"),
                });
            server.api.add_method("/nuvola/core/get_top_runner", Drt.RpcFlags.READABLE, null, handle_get_top_runner, null);
            server.api.add_method("/nuvola/core/list_apps", Drt.RpcFlags.READABLE,
                "Returns information about all installed web apps.",
                handle_list_apps,  null);
            server.api.add_method("/nuvola/core/get_app_info", Drt.RpcFlags.READABLE,
                "Returns information about a web app",
                handle_get_app_info, {
                    new Drt.StringParam("id", true, false, null, "Application id"),
                });
            server.api.add_notification(APP_STARTED, Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE,
                "Emitted when a new app is launched.");
            server.api.add_notification(APP_EXITED, Drt.RpcFlags.WRITABLE|Drt.RpcFlags.SUBSCRIBE,
                "Emitted when a app has exited.");
            server.start();
        } catch (Drt.IOError e) {
            warning("Master server error: %s", e.message);
            quit();
            return;
        }

        init_tiliado_account();

        storage_server = new Drt.KeyValueStorageServer(server.api);
        storage_server.add_provider("master.config", config);

        var key_grabber = new XKeyGrabber();
        var key_binder = new GlobalActionsKeyBinder(key_grabber, config);
        actions_key_binder = new ActionsKeyBinderServer(server, key_binder, app_runners);
        media_keys = new MediaKeysServer(new MediaKeys(this.app_id, key_grabber), server, app_runners);

        #if EXPERIMENTAL
        storage.assert_data_file("www/engine.io.js");
        var www_root_dirname = "www";
        File[] www_roots = {storage.user_data_dir.get_child(www_root_dirname)};
        foreach (var data_dir in storage.data_dirs) {
            www_roots += data_dir.get_child(www_root_dirname);
        }
        http_remote_control = new HttpRemoteControl.Server(
            this, server, app_runners_map, app_runners, www_roots);
        #endif
        initialized = true;
    }

    private void handle_runner_started(Drt.RpcRequest request) throws Drt.RpcError {
        var app_id = request.pop_string();
        var api_token = request.pop_string();
        var runner = app_runners_map[app_id];
        return_val_if_fail(runner != null, null);

        var channel = request.connection as Drt.RpcChannel;
        if (channel == null) {
            throw new Drt.RpcError.REMOTE_ERROR(
                "Failed to connect runner '%s'. %s ", app_id, request.connection.get_type().name());
        }
        channel.api_token = api_token;
        runner.connect_channel(channel);
        debug("Connected to runner server for '%s'.", app_id);
        server.api.emit(APP_STARTED, app_id, app_id);
        request.respond(new Variant.boolean(true));
    }

    private void handle_runner_activated(Drt.RpcRequest request) throws Drt.RpcError {
        var app_id = request.pop_string();
        var runner = app_runners_map[app_id];
        return_val_if_fail(runner != null, false);

        if (!app_runners.remove(runner)) {
            critical("Runner for '%s' not found in queue.", runner.app_id);
        }
        app_runners.push_head(runner);
        request.respond(new Variant.boolean(true));
    }

    private void handle_get_top_runner(Drt.RpcRequest request) throws Drt.RpcError {
        var runner = app_runners.peek_head();
        request.respond(new Variant("ms", runner == null ? null : runner.app_id));
    }

    private void handle_list_apps(Drt.RpcRequest request) throws Drt.RpcError {
        var builder = new VariantBuilder(new VariantType("aa{sv}"));
        var keys = app_runners_map.get_keys();
        keys.sort(string.collate);
        foreach (var app_id in keys)
        builder.add_value(app_runners_map[app_id].query_meta());
        request.respond(builder.end());
    }

    private void handle_get_app_info(Drt.RpcRequest request) throws Drt.RpcError {
        var app_id = request.pop_string();
        var app = app_runners_map[app_id];
        request.respond(app != null ? app.query_meta() : null);
    }

    public async void start_app(string app_id) {
        hold();
        #if FLATPAK && NUVOLA_RUNTIME
        try {
            var uid = WebApp.build_uid_from_app_id(app_id);
            var path = "/" + uid.replace(".", "/");
            var app_api = yield Bus.get_proxy<AppDbusIfce>(
                BusType.SESSION, uid, path,
                DBusProxyFlags.DO_NOT_CONNECT_SIGNALS|DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
            app_api.activate();
            debug("DBus activation of %s succeeded.", uid);
            Timeout.add_seconds(5, () => {release(); return false;});
        }
        catch (GLib.Error e) {
            warning("DBus Activation error: %s", e.message);
            var dialog = new Drtgtk.ErrorDialog(
                "Web App Loading Error",
                ("The web application with id '%s' has not been found.\n\n"
                    + "DBus Activation has ended with an error:\n%s").printf(app_id, e.message));
            dialog.run();
            dialog.destroy();
            release();
        }
        #else
        var app_meta = web_app_reg.get_app_meta(app_id);
        if (app_meta == null) {
            var dialog = new Drtgtk.ErrorDialog(
                "Web App Loading Error",
                "The web application with id '%s' has not been found.".printf(app_id));
            dialog.run();
            dialog.destroy();
            release();
            return;
        }

        string[] argv = new string[exec_cmd.length + 3];
        for (var i = 0; i < exec_cmd.length; i++) {
            argv[i] = exec_cmd[i];
        }
        var j = exec_cmd.length;
        argv[j++] = "-a";
        argv[j++] = app_meta.data_dir.get_path();
        argv[j++] = null;

        AppRunner runner;
        debug("Launch app runner for '%s': %s", app_id, string.joinv(" ", argv));
        try {
            runner = new SubprocessAppRunner(app_id, argv, server.router.hex_token);
        } catch (GLib.Error e) {
            warning("Failed to launch app runner for '%s'. %s", app_id, e.message);
            var dialog = new Drtgtk.ErrorDialog(
                "Web App Loading Error",
                "The web application '%s' has failed to load.".printf(app_meta.name));
            dialog.run();
            dialog.destroy();
            release();
            return;
        }

        runner.exited.connect(on_runner_exited);
        app_runners.push_tail(runner);

        if (app_id in app_runners_map) {
            debug("App runner for '%s' is already running.", app_id);
        } else {
            app_runners_map[app_id] = runner;
        }
        #endif
    }

    public bool start_app_from_dbus(string app_id, string dbus_id, out string token) {
        token = null;
        hold();
        late_init();
        AppRunner runner;
        token = null;
        debug("Launch app runner for '%s': %s", app_id, dbus_id);
        try {
            runner = new DbusAppRunner(app_id, dbus_id, server.router.hex_token);
            token = server.router.hex_token;
        } catch (GLib.Error e) {
            warning("Failed to launch app runner for '%s'. %s", app_id, e.message);
            var dialog = new Drtgtk.ErrorDialog(
                "Web App Loading Error",
                "The web application '%s' has failed to load.".printf(dbus_id));
            dialog.run();
            dialog.destroy();
            release();
            return false;
        }

        runner.exited.connect(on_runner_exited);
        app_runners.push_tail(runner);

        if (app_id in app_runners_map) {
            debug("App runner for '%s' is already running.", app_id);
        } else {
            app_runners_map[app_id] = runner;
        }
        return true;
    }

    private void on_runner_exited(AppRunner runner) {
        debug("Runner exited: %s, was connected: %s", runner.app_id, runner.connected.to_string());
        runner.exited.disconnect(on_runner_exited);
        if (!app_runners.remove(runner)) {
            critical("Runner for '%s' not found in queue.", runner.app_id);
        }
        if (app_runners_map[runner.app_id] == runner) {
            app_runners_map.remove(runner.app_id);
        }
        server.api.emit(APP_EXITED, runner.app_id, runner.app_id);
        runner_exited(runner);
        release();
    }

    private void init_tiliado_account() {
        #if TILIADO_API
        assert(TILIADO_OAUTH2_CLIENT_ID != null && TILIADO_OAUTH2_CLIENT_ID[0] != '\0');
        var tiliado = new TiliadoApi2(
            TILIADO_OAUTH2_CLIENT_ID, Drt.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data),
            TILIADO_OAUTH2_API_ENDPOINT, TILIADO_OAUTH2_TOKEN_ENDPOINT, null, "nuvolaplayer");
        activation = new TiliadoActivationManager(tiliado, server, config);
        if (activation.get_user_info() == null) {
            activation.update_user_info_sync();
        }
        #endif
    }
}

} // namespace Nuvola
