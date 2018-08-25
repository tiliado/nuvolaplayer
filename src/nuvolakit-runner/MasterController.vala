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
    public TiliadoPaywall? paywall {get; private set; default = null;}
    public bool debuging {get; private set; default = false;}
    public string? machine_hash {get; private set; default = null;}
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
        base(Nuvola.get_app_uid(), Nuvola.get_app_name(), Nuvola.get_dbus_id());
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

    public unowned MasterUserInterface get_ui() {
        if (_ui == null) {
            late_init();
            init_tiliado_account();
            _ui = new MasterUserInterface(this);
        }
        return _ui;
    }

    private void late_init() {
        if (initialized) {
            return;
        }

        var loop = new MainLoop();
        Nuvola.get_machine_hash.begin((o, res) => {
            machine_hash = Nuvola.get_machine_hash.end(res);
            loop.quit();
        });
        loop.run();

        app_runners = new Queue<AppRunner>();
        app_runners_map = new HashTable<string, AppRunner>(str_hash, str_equal);
        var default_config = new HashTable<string, Variant>(str_hash, str_equal);
        config = new Config(storage.user_config_dir.get_child("master").get_child("config.json"), default_config);

        string server_name = build_master_ipc_id();
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
                handle_list_apps, null);
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
        foreach (File data_dir in storage.data_dirs()) {
            www_roots += data_dir.get_child(www_root_dirname);
        }
        http_remote_control = new HttpRemoteControl.Server(
            this, server, app_runners_map, app_runners, www_roots);
        #endif
        initialized = true;
    }

    private void handle_runner_started(Drt.RpcRequest request) throws Drt.RpcError {
        string? app_id = request.pop_string();
        string? api_token = request.pop_string();
        AppRunner runner = app_runners_map[app_id];
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
        string? app_id = request.pop_string();
        AppRunner runner = app_runners_map[app_id];
        return_val_if_fail(runner != null, false);

        if (!app_runners.remove(runner)) {
            critical("Runner for '%s' not found in queue.", runner.app_id);
        }
        app_runners.push_head(runner);
        request.respond(new Variant.boolean(true));
    }

    private void handle_get_top_runner(Drt.RpcRequest request) throws Drt.RpcError {
        AppRunner runner = app_runners.peek_head();
        request.respond(new Variant("ms", runner == null ? null : runner.app_id));
    }

    private void handle_list_apps(Drt.RpcRequest request) throws Drt.RpcError {
        var builder = new VariantBuilder(new VariantType("aa{sv}"));
        List<unowned string> keys = app_runners_map.get_keys();
        keys.sort(string.collate);
        foreach (unowned string app_id in keys) {
            builder.add_value(app_runners_map[app_id].query_meta());
        }
        request.respond(builder.end());
    }

    private void handle_get_app_info(Drt.RpcRequest request) throws Drt.RpcError {
        string? app_id = request.pop_string();
        AppRunner app = app_runners_map[app_id];
        request.respond(app != null ? app.query_meta() : null);
    }

    public async void start_app(string app_id) {
        hold();
        #if FLATPAK && NUVOLA_RUNTIME
        assert_not_reached();
        #else
        WebApp? app_meta = web_app_reg.get_app_meta(app_id);
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
        int j = exec_cmd.length;
        argv[j++] = "-a";
        argv[j++] = app_meta.data_dir.get_path();
        argv[j++] = null;
        try {
            GLib.Pid child_pid;
            debug("Launch app runner for '%s': %s", app_id, string.joinv(" ", argv));
            GLib.Process.spawn_async(
                null, argv, null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out child_pid);
            ChildWatch.add(child_pid, (pid, status) => {GLib.Process.close_pid(pid); release();});
        } catch (GLib.Error e) {
            warning("Failed to launch app runner for '%s'. %s", app_id, e.message);
            var dialog = new Drtgtk.ErrorDialog(
                "Web App Loading Error",
                "The web application '%s' has failed to load. %s".printf(app_meta.name, e.message));
            dialog.run();
            dialog.destroy();
            release();
            return;
        }
        #endif
    }

    public bool start_app_from_dbus(string app_id, string dbus_id, GLib.BusName sender_id, out string token) {
        token = null;
        hold();
        late_init();
        AppRunner runner;
        token = null;
        debug("Launch app runner for '%s': %s %s", app_id, dbus_id, sender_id);
        try {
            runner = new DbusAppRunner(app_id, dbus_id, sender_id, server.router.hex_token);
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
        TiliadoActivation? activation = TiliadoActivation.create_if_enabled(config);
        if (activation != null) {
            var gumroad = new TiliadoGumroad(config, Drt.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data));
            paywall = new TiliadoPaywall(this, activation, gumroad);
            paywall.refresh_data.begin((o, res) => {paywall.refresh_data.end(res);});
        }
    }
}

} // namespace Nuvola
