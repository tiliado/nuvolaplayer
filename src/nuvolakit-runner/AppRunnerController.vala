/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

private extern const bool CEF_DEFAULT;

public string build_ui_runner_ipc_id(string web_app_id) {
    return "N3" + web_app_id.replace("_", "");
}

public class AppRunnerController: Drtgtk.Application {
    public Drt.Storage storage {get; private set;}
    public Config config {get; protected set; default = null;}
    public Connection connection {get; protected set;}
    public WebAppWindow? main_window {get; protected set; default = null;}
    public WebApp web_app {get; protected set;}
    public WebAppStorage app_storage {get; protected set;}
    public string? machine_hash {get; private set; default = null;}
    public MasterService master {get; private set;}
    private WebOptions? web_options;
    public WebEngine web_engine {get; private set;}
    public Bindings bindings {get; private set;}
    public IpcBus ipc_bus {get; private set; default=null;}
    public ActionsHelper actions_helper {get; private set; default = null;}
    private AppDbusApi? dbus_api = null;
    private uint dbus_api_id = 0;
    private GlobalKeybindings? global_keybindings;
    private const int MINIMAL_REMEMBERED_WINDOW_SIZE = 300;
    private uint configure_event_cb_id = 0;
    private MenuBar menu_bar;
    private Drtgtk.Form? init_form = null;
    private SList<Component> components = null;
    private HashTable<string, Variant>? web_worker_data = null;
    private StartupResult? startup_model;
    private TiliadoPaywall? tiliado_paywall = null;
    private URLBar? url_bar = null;
    private HashTable<string, Gtk.InfoBar> info_bars;
    private MainLoopAdaptor? mainloop = null;
    private AboutDialog? about_dialog = null;
    private PreferencesDialog? preferences_dialog = null;
    private StartupPhase startup_phase = StartupPhase.NONE;
    private uint setup_sidebar_timeout_id = 0;

    public AppRunnerController(
        Drt.Storage storage, WebApp web_app, WebAppStorage app_storage) {
        string uid = web_app.get_uid();
        base(uid, web_app.name);
        this.web_app = web_app;
        this.storage = storage;
        this.icon = web_app.get_icon_name();
        this.version = "%d.%d".printf(web_app.version_major, web_app.version_minor);
        this.app_storage = app_storage;
        this.info_bars = new HashTable<string, Gtk.InfoBar>(str_hash, str_equal);
    }

    public signal void info_bar_response(string id, int reponse_id);

    public override bool dbus_register(DBusConnection conn, string object_path)
    throws GLib.Error {
        if (!base.dbus_register(conn, object_path)) {
            return false;
        }
        dbus_api = new AppDbusApi(this);
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

    private void start() {
        window_removed.connect(on_window_removed);
        init_settings();
        init_base_actions();
        init_ipc();
        startup_model = new StartupResult();
        startup_phase = StartupPhase.IN_PROGRESS;
        do_about();
        web_app.scale_factor = about_dialog.scale_factor * 1.0;
        debug("Scale factor: %d", about_dialog.scale_factor);
        hold();
        var startup_check = new StartupCheck(this, startup_model, about_dialog, web_app);
        startup_check.run.begin(web_options, on_startup_check_run_done);
    }

    private void on_startup_check_run_done(GLib.Object? object, AsyncResult res) {
        release();
        var startup = (StartupCheck) object;
        assert(startup != null);
        StartupStatus status = startup.run.end(res);
        machine_hash = (owned) startup.machine_hash;
        master = startup.master;
        tiliado_paywall = startup.paywall;

        switch (status) {
        case StartupStatus.WARNING:
            startup_phase = StartupPhase.WARNING;
            Gtk.Label label = Drtgtk.Labels.markup("%s script has a few issues but it can start.", app_name);
            about_dialog.show_action(label, "Continue", Gtk.ResponseType.OK, Gtk.MessageType.WARNING);
            about_dialog.show_tab(AboutDialog.TAB_STARTUP);
            break;
        case StartupStatus.OK:
            startup_phase = StartupPhase.CHECKS_DONE;
            show_welcome_note_or_continue();
            break;
        default:
            startup_phase = StartupPhase.ERROR;
            #if GENUINE
            Gtk.Label label = Drtgtk.Labels.markup(
                "<b>%s script cannot start.</b> <a href=\"%s\">Get help</a>.",
                app_name, Nuvola.HELP_URL);
            #else
            Gtk.Label label = Drtgtk.Labels.markup(
                "<b>%s script cannot start.</b>\n<a href=\"%s\">Get genuine Nuvola Player</a>"
                + " or contact your distributor.", app_name, "https://nuvola.tiliado.eu");
            #endif
            about_dialog.show_action(label, "Quit", Gtk.ResponseType.OK, Gtk.MessageType.ERROR);
            about_dialog.show_tab(AboutDialog.TAB_STARTUP);
            break;
        }
    }

    private void show_welcome_note_or_continue() {
        if (about_dialog.show_welcome_note(this.master.config ?? this.config)) {
            startup_phase = StartupPhase.WELCOME;
        } else {
            show_terms();
        }
    }

    private void show_terms() {
        #if FLATPAK
        Drt.KeyValueStorage config = this.master.config ?? this.config;
        if (tiliado_paywall != null && AboutDialog.TERMS_VERSION > config.get_int64("nuvola.terms")) {
            startup_phase = StartupPhase.TERMS;
            about_dialog.show_terms();
        } else {
            finish_startup();
        }
        #else
        finish_startup();
        #endif
    }

    private void terms_accepted() {
        Drt.KeyValueStorage config = this.master.config ?? this.config;
        config.set_int64("nuvola.terms", AboutDialog.TERMS_VERSION);
        finish_startup();
    }

    private void finish_startup() {
        Gtk.Label label = Drtgtk.Labels.markup("%s will load in a few seconds.", app_name);
        about_dialog.show_progress(label);
        startup_phase = StartupPhase.ALL_DONE;

        if (tiliado_paywall != null && !tiliado_paywall.unlocked) {
            var loop = new MainLoop();
            tiliado_paywall.start_trial.begin((o, res) => {
                tiliado_paywall.start_trial.end(res);
                loop.quit();
            });
            loop.run();
        }

        init_gui();
        init_web_engine();
        if (about_dialog != null) {
            about_dialog.close();
        }

        if (!config.get_bool("infobar.feature_voting_closed")) {
            show_info_bar(
                "feature-voting",
                Gtk.MessageType.INFO,
                "<b>Nuvola users are going to vote for feature requests in March 2021.</b>\n"
                + "We need your help to find out which feature requests are most wanted or not relevant anymore. "
                + "You can propose new features or improve existing requests.",
                {"More information"}
            );
        }
    }

    private void init_settings() {
        /* Disable GStreamer plugin helper because it is shown too often and quite annoying.  */
        Environment.set_variable("GST_INSTALL_PLUGINS_HELPER", "/bin/true", true);
        web_worker_data = new HashTable<string, Variant>(str_hash, str_equal);

        Gtk.Settings gtk_settings = Gtk.Settings.get_default();
        var default_config = new HashTable<string, Variant>(str_hash, str_equal);
        default_config.insert(ConfigKey.WINDOW_X, new Variant.int64(-1));
        default_config.insert(ConfigKey.WINDOW_Y, new Variant.int64(-1));
        default_config.insert(ConfigKey.WINDOW_SIDEBAR_POS, new Variant.int64(-1));
        default_config.insert(ConfigKey.WINDOW_SIDEBAR_VISIBLE, new Variant.boolean(false));
        default_config.insert(
            ConfigKey.DARK_THEME, new Variant.boolean(web_app.dark_theme));
        default_config.insert(
            ConfigKey.DARK_SCROLLBAR, new Variant.boolean(web_app.dark_theme));
        default_config.insert(
            ConfigKey.SYSTEM_DECORATIONS, new Variant.boolean(false));
        config = new Config(app_storage.config_dir.get_child("config.json"), default_config);
        config.changed.connect(on_config_changed);
        gtk_settings.gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
        shell.client_side_decorations = !config.get_bool(ConfigKey.SYSTEM_DECORATIONS);
        connection = new Connection(new Soup.Session(), app_storage.cache_dir.get_child("conn"), config);

        #if HAVE_CEF
        web_options = WebOptions.create(typeof(CefOptions), app_storage, connection);
        #else
        web_options = WebOptions.create(typeof(DummyOptions), app_storage, connection);
        #endif

        config.set_default_value(ConfigKey.GTK_THEME, Drtgtk.DesktopShell.get_gtk_theme());
        if (config.has_key(ConfigKey.GTK_THEME)) {
            string theme_name = config.get_string(ConfigKey.GTK_THEME);
            if (theme_name == Drtgtk.DesktopShell.get_initial_gtk_theme()) {
                // Unset the value to track user's global theme.
                config.unset(ConfigKey.GTK_THEME);
            }
            if (theme_name != null && theme_name != "") {
                Drtgtk.DesktopShell.set_gtk_theme(theme_name);
            }
        }

        #if FLATPAK
        string theme = Drtgtk.DesktopShell.get_gtk_theme();
        if (!Drtgtk.DesktopShell.gtk_theme_exists(theme)) {
            warning("GTK+ theme '%s' does not exist, using '%s' theme instead.", theme, Drtgtk.DEFAULT_GTK_THEME);
            Drtgtk.DesktopShell.set_gtk_theme(Drtgtk.DEFAULT_GTK_THEME);
        }
        #endif
    }

    private void init_base_actions() {
        actions_helper = new ActionsHelper(actions, config);
        unowned ActionsHelper ah = actions_helper;
        Drtgtk.Action[] actions_spec = {
            //          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
            ah.simple_action("main", "app", Actions.ACTIVATE, "Activate main window", null, null, null, do_activate),
            ah.simple_action("main", "app", Actions.QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
            ah.simple_action("main", "app", Actions.NEWS, "News", "_News", null, null, do_show_news),
            ah.simple_action("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
            ah.simple_action("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
            ah.simple_action("main", "app", Actions.REPORT_BUG, "Report bug", null, null, null, do_report_bug),
            ah.simple_action("main", "app", Actions.ASK_QUESTION, "Ask question", null, null, null, do_ask_question),
            ah.simple_action("main", "app", Actions.REQUEST_FEATURE, "Suggest feature", null, null, null, do_request_feature),
        };
        actions.add_actions(actions_spec);
        set_app_menu_items({
            Actions.REPORT_BUG, Actions.ASK_QUESTION, Actions.REQUEST_FEATURE,
            Actions.HELP, Actions.NEWS, Actions.ABOUT, Actions.QUIT});
    }

    private void init_ipc() {
        string bus_name = build_ui_runner_ipc_id(web_app.id);
        web_worker_data["WEB_APP_ID"] = web_app.id;
        web_worker_data["RUNNER_BUS_NAME"] = bus_name;
        ipc_bus = new IpcBus(bus_name);
        ipc_bus.router.add_method(IpcApi.CORE_GET_METADATA, Drt.RpcFlags.READABLE|Drt.RpcFlags.PRIVATE,
            "Get web app metadata.", handle_get_metadata, null);
        ipc_bus.router.add_method("/nuvola/core/get-component-info", Drt.RpcFlags.READABLE,
            "Get info about component.",
            handle_get_component_info, {
                new Drt.StringParam("name", true, false, null, "Component name.")
            });
        ipc_bus.router.add_method("/nuvola/core/toggle-component-active", Drt.RpcFlags.WRITABLE|Drt.RpcFlags.PRIVATE,
            "Set whether the component is active.",
            handle_toggle_component_active, {
                new Drt.StringParam("name", true, false, null, "Component name."),
                new Drt.BoolParam("name", true, false, "Component active state.")
            });
        ipc_bus.router.add_method("/nuvola/show-info-bar", Drt.RpcFlags.WRITABLE|Drt.RpcFlags.PRIVATE,
            "Show info bar.",
            handle_show_info_bar, {
                new Drt.StringParam("id", true, false, null, "Info bar id."),
                new Drt.DoubleParam("type", true, null, "Info bar type."),
                new Drt.StringParam("name", true, false, null, "Info bar text.")
            });
        try {
            ipc_bus.start();
        } catch (Drt.IOError e) {
            error("Failed to start IPC server. %s", e.message);
        }
    }

    private void init_gui() {
        menu_bar = new MenuBar(this);
        menu_bar.update();
        main_window = new WebAppWindow(this);
        main_window.can_destroy.connect(on_can_quit);
        var x = (int) config.get_int64(ConfigKey.WINDOW_X);
        var y = (int) config.get_int64(ConfigKey.WINDOW_Y);
        if (x >= 0 && y >= 0) {
            main_window.move(x, y);
        }
        var win_width = (int) config.get_int64(ConfigKey.WINDOW_WIDTH);
        var win_height = (int) config.get_int64(ConfigKey.WINDOW_HEIGHT);
        if (win_width > MINIMAL_REMEMBERED_WINDOW_SIZE && win_height > MINIMAL_REMEMBERED_WINDOW_SIZE) {
            main_window.resize(win_width, win_height);
        }
        if (config.get_bool(ConfigKey.WINDOW_MAXIMIZED)) {
            main_window.maximize();
        }
        main_window.present();
        main_window.window_state_event.connect(on_window_state_event);
        main_window.configure_event.connect(on_configure_event);
        main_window.notify["is-active"].connect_after(on_window_is_active_changed);
        main_window.sidebar.hide();
        main_window.sidebar.frozen = true;
        main_window.sidebar_position = (int) config.get_int64(ConfigKey.WINDOW_SIDEBAR_POS);
        main_window.notify["sidebar-position"].connect_after((o, p) => {
            config.set_int64(ConfigKey.WINDOW_SIDEBAR_POS, (int64) main_window.sidebar_position);
        });
        main_window.sidebar.add_page.connect_after(on_sidebar_page_added);
        main_window.sidebar.remove_page.connect_after(on_sidebar_page_removed);
        main_window.sidebar.notify["visible"].connect_after(on_sidebar_visibility_changed);
        main_window.sidebar.page_changed.connect(on_sidebar_page_changed);

        fatal_error.connect(on_fatal_error);
        show_error.connect(on_show_error);
        show_warning.connect(on_show_warning);
        info_bar_response.connect(on_info_bar_response);

        show_deprecation();
    }

    private void show_deprecation() {
        if (web_app.is_deprecated()) {
            info_bar_response.connect((id, response_id) => {
                if (id == "deprecation" && response_id == 0) {
                    show_uri(web_app.deprecation_url);
                }
            });

            show_info_bar(
                "deprecation",
                Gtk.MessageType.WARNING,
                Markup.printf_escaped("<b>%s</b> app is deprecated. It may be removed in future versions.", web_app.name),
                {"More information"}
            );
        }
    }

    private void init_web_engine() {
        web_engine = web_options.create_web_engine(web_app);
        web_worker_data["JS_ENGINE"] = web_options.get_name_version();
        web_worker_data["JS_ENGINE_NAME"] = web_options.get_name();
        web_worker_data["JS_ENGINE_VERSION"] = web_options.engine_version.to_string();
        web_worker_data["JS_HOSTNAME"] = Drt.System.get_hostname();
        web_worker_data["JS_MACHINE_HASH"] = machine_hash;
        web_engine.early_init(this, ipc_bus, config, connection, web_worker_data);
        web_engine.init_form.connect(on_init_form);
        web_engine.notify.connect_after(on_web_engine_notify);
        web_engine.show_alert_dialog.connect(on_show_alert_dialog);
        web_engine.show_script_dialog.connect(on_show_script_dialog);
        actions.action_changed.connect(on_action_changed);
        Gtk.Widget widget = web_engine.get_main_web_view();
        widget.hexpand = widget.vexpand = true;
        main_window.grid.add(widget);
        widget.show();
        web_engine.init_finished.connect(init_app_runner);
        web_engine.app_runner_ready.connect(load_app);

        /* It is necessary to init WebEngine after format support check because WebKitPluginProcess2
         * must not be terminated during plugin discovery process. Issue: tiliado/nuvolaruntime#354 */
        web_engine.init();
    }

    private void init_app_runner() {
        append_actions();
        if (ipc_bus.master != null) {
            var gakb = new ActionsKeyBinderClient(ipc_bus.master);
            global_keybindings = new GlobalKeybindings(gakb, actions);
        }
        load_extensions();
        web_engine.get_main_web_view().hide();
        web_engine.init_app_runner();
    }

    private void load_app() {
        set_app_menu_items({
            Actions.PREFERENCES, Actions.REPORT_BUG, Actions.ASK_QUESTION, Actions.REQUEST_FEATURE,
            Actions.HELP, Actions.NEWS, Actions.ABOUT, Actions.QUIT});
        main_window.set_menu_button_items({
            Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|",
            Actions.TOGGLE_SIDEBAR, "|", Actions.GO_LOAD_URL});
        main_window.create_toolbar({Actions.GO_BACK, Actions.GO_FORWARD, Actions.GO_RELOAD, Actions.GO_HOME});
        web_engine.get_main_web_view().show();

        menu_bar.set_menu("01_go", "_Go", {Actions.GO_HOME, Actions.GO_RELOAD, Actions.GO_BACK, Actions.GO_FORWARD});
        menu_bar.set_menu("02_view", "_View", {Actions.ZOOM_IN, Actions.ZOOM_OUT, Actions.ZOOM_RESET, "|", Actions.TOGGLE_SIDEBAR});
        web_engine.load_app();
    }

    public override void activate() {
        if (main_window != null) {
            main_window.present();
        } else if (about_dialog != null) {
            about_dialog.present();
        } else {
            start();
        }
    }

    private void append_actions() {
        unowned ActionsHelper ah = actions_helper;
        Drtgtk.Action[] actions_spec = {
            ah.simple_action("main", "app", Actions.PREFERENCES, "Preferences", "_Preferences", null, null, do_preferences),
            ah.toggle_action("main", "win", Actions.TOGGLE_SIDEBAR, "Show sidebar", "Show _sidebar", null, null, do_toggle_sidebar, false),
            ah.simple_action("go", "app", Actions.GO_HOME, "Home", "_Home", "go-home", "<alt>Home", web_engine.go_home),
            ah.simple_action("go", "app", Actions.GO_BACK, "Back", "_Back", "go-previous", "<alt>Left", web_engine.go_back),
            ah.simple_action("go", "app", Actions.GO_FORWARD, "Forward", "_Forward", "go-next", "<alt>Right", web_engine.go_forward),
            ah.simple_action("go", "app", Actions.GO_RELOAD, "Reload", "_Reload", "view-refresh", "<ctrl>R", web_engine.reload),
            ah.simple_action("go", "app", Actions.GO_LOAD_URL, "Load URL...", null, null, "<ctrl>L", do_load_url),
            ah.simple_action("view", "win", Actions.ZOOM_IN, "Zoom in", null, "zoom-in", "<ctrl>plus", web_engine.zoom_in),
            ah.simple_action("view", "win", Actions.ZOOM_OUT, "Zoom out", null, "zoom-out", "<ctrl>minus", web_engine.zoom_out),
            ah.simple_action("view", "win", Actions.ZOOM_RESET, "Original zoom", null, "zoom-original", "<ctrl>0", web_engine.zoom_reset),
        };
        actions.add_actions(actions_spec);
        actions.get_action(Actions.GO_FORWARD).enabled = web_engine.can_go_forward;
        actions.get_action(Actions.GO_BACK).enabled = web_engine.can_go_back;
    }

    private void do_quit() {
        List<unowned Gtk.Window> windows = Gtk.Window.list_toplevels();
        foreach (Gtk.Window window in windows) {
            window.hide();
        }
        Timeout.add(50, () => {quit_mainloop(); quit(); return false;});
        Timeout.add_seconds(5, () => {warning("Force quit after timeout."); GLib.Process.exit(0);});
    }

    public void shutdown_engines() {
        web_options.shutdown();
    }

    public override void startup() {
        base.startup();
        var source = new IdleSource();
        source.set_callback(() => {
            run_mainloop();
            return false;
        });
        source.set_priority(GLib.Priority.HIGH);
        source.set_can_recurse(false);
        source.attach(MainContext.ref_thread_default());
    }

    public override void run_mainloop() {
        if (mainloop == null) {
            mainloop = new GlibMainLoopAdaptor();
        }
        while (mainloop != null) {
            mainloop.run();
            mainloop = mainloop.get_replacement();
        }
    }

    public override void quit_mainloop() {
        if (mainloop != null) {
            mainloop.quit();
        }
    }

    public void replace_mainloop(MainLoopAdaptor replacement) {
        if (mainloop == null) {
            mainloop = replacement;
        } else {
            mainloop.replace(replacement);
        }
    }

    private void do_activate() {
        activate();
    }

    private void do_preferences() {
        if (preferences_dialog != null) {
            preferences_dialog.present();
            return;
        }
        var form_values = new HashTable<string, Variant>(str_hash, str_equal);
        var form = new Drtgtk.Form(form_values);
        try {
            Variant? extra_form_values = null;
            Variant? extra_form_entries = null;
            web_engine.get_preferences(out extra_form_values, out extra_form_entries);
            form.add_values(Drt.VariantUtils.to_hash_table(extra_form_values));
            form.add_entries(extra_form_entries);
        } catch (Drtgtk.FormError e) {
            show_error("Preferences form error",
                "Some entries of the Preferences form haven't been shown because of malformed form specification: %s"
                .printf(e.message));
        }

        preferences_dialog = new PreferencesDialog(
            this, main_window, new NetworkSettings(connection), new AppearanceSettings(config),
            new KeybindingsSettings(
                this, actions, config, global_keybindings != null ? global_keybindings.keybinder : null),
            new ComponentsManager(this, components, tiliado_paywall), form);
        preferences_dialog.response.connect(on_preferences_dialog_response);
        preferences_dialog.present();
    }

    private void on_preferences_dialog_response(int response_id) {
        assert(preferences_dialog != null);

        HashTable<string, Variant> new_values = preferences_dialog.web_app_form.get_values();
        foreach (unowned string? key in new_values.get_keys()) {
            Variant? new_value = new_values.get(key);
            if (new_value == null) {
                critical("New value '%s' not found", key);
            } else {
                config.set_value(key, new_value);
            }
        }
        NetworkProxyType type;
        string? host;
        int port;
        if (preferences_dialog.network_settings.get_proxy_settings(out type, out host, out port)) {
            debug("New network proxy settings: %s %s %d", type.to_string(), host, port);
            connection.set_network_proxy(type, host, port);
            if (!web_engine.apply_network_proxy(connection)) {
                show_info_bar(
                    "proxy-warning", Gtk.MessageType.WARNING,
                    "You need to restart the application to apply new network proxy settings.");
            }
        }

        // Don't destroy dialog before form data are retrieved
        preferences_dialog.response.disconnect(on_preferences_dialog_response);
        preferences_dialog.destroy();
        preferences_dialog = null;
    }

    private void do_about() {
        if (about_dialog == null) {
            about_dialog = new AboutDialog(
                main_window, storage, new StartupView(this, startup_model), web_app,
                web_options, new PatronBox());
            about_dialog.show_close_button(startup_phase == StartupPhase.ALL_DONE);
            about_dialog.response.connect_after(on_about_dialog_response);
        }
        about_dialog.present();
    }

    private void on_about_dialog_response(Gtk.Dialog dialog, int response_id) {
        switch (startup_phase) {
        case StartupPhase.IN_PROGRESS:
        case StartupPhase.ERROR:
            dialog.hide();
            do_quit();
            break;
        case StartupPhase.WARNING:
            show_welcome_note_or_continue();
            break;
        case StartupPhase.WELCOME:
            show_terms();
            break;
        case StartupPhase.TERMS:
            if (response_id == Gtk.ResponseType.ACCEPT) {
                terms_accepted();
            } else {
                dialog.hide();
                do_quit();
            }
            break;
        case StartupPhase.ALL_DONE:
            about_dialog = null;
            dialog.response.disconnect(on_about_dialog_response);
            dialog.destroy();
            break;
        default:
            warning("Unexpected start-up phase: %s (response id %d).", startup_phase.to_string(), response_id);
            break;
        }
    }

    private void do_toggle_sidebar() {
        Sidebar sidebar = main_window.sidebar;
        if (sidebar.visible) {
            sidebar.hide();
        } else {
            sidebar.show();
            string? sidebar_page = config.get_string(ConfigKey.WINDOW_SIDEBAR_PAGE);
            if (sidebar_page != null && sidebar.has_page(sidebar_page) && sidebar.page != sidebar_page) {
                sidebar.page = sidebar_page;
            }
        }
    }

    private void do_help() {
        show_uri(Nuvola.HELP_URL);
    }

    private void do_show_news() {
        show_uri(Drt.String.not_empty_or(Nuvola.NEWS_URL, Nuvola.HELP_URL));
    }

    private void do_report_bug() {
        show_uri(Drt.String.not_empty_or(Nuvola.REPORT_BUG_URL, Nuvola.HELP_URL));
    }

    private void do_ask_question() {
        show_uri(Drt.String.not_empty_or(Nuvola.ASK_QUESTION_URL, Nuvola.HELP_URL));
    }

    private void do_request_feature() {
        show_uri(Drt.String.not_empty_or(Nuvola.REQUEST_FEATURE_URL, Nuvola.HELP_URL));
    }

    private void do_load_url() {
        string? url = web_engine.get_url();
        if (url_bar == null) {
            url_bar = new URLBar((owned) url);
        } else {
            url_bar.url = (owned) url;
        }
        Gtk.HeaderBar header_bar = main_window.header_bar;
        if (header_bar.custom_title != url_bar) {
            url_bar.show();
            header_bar.custom_title = url_bar;
            url_bar.response.connect(on_url_bar_response);
        }
        url_bar.entry.grab_focus();
    }

    private void on_url_bar_response(URLBar bar, bool response) {
        main_window.header_bar.custom_title = null;
        url_bar = null;
        bar.response.disconnect(on_url_bar_response);
        if (response) {
            string? url = bar.url;
            if (!Drt.String.is_empty(url)) {
                web_engine.load_url(url);
            }
        }
    }

    private void load_extensions() {
        Drt.RpcRouter router = ipc_bus.router;
        WebWorker web_worker = web_engine.web_worker;
        bindings = new Bindings();
        bindings.add_binding(new ActionsBinding(router, web_worker));
        bindings.add_binding(new NotificationsBinding(router, web_worker));
        bindings.add_binding(new NotificationBinding(router, web_worker));
        bindings.add_binding(new LauncherBinding(router, web_worker));
        bindings.add_binding(new MediaKeysBinding(router, web_worker));
        bindings.add_binding(new MenuBarBinding(router, web_worker));
        bindings.add_binding(new MediaPlayerBinding(router, web_worker, new MediaPlayer(actions)));
        bindings.add_object(actions_helper);

        components = new SList<Component>();
        components.prepend(new TrayIconComponent(this, bindings, config));
        components.prepend(new AudioTweaksComponent(this, bindings, config));
        components.prepend(new UnityLauncherComponent(this, bindings, config));
        components.prepend(new NotificationsComponent(this, bindings, actions_helper));
        components.prepend(new MediaKeysComponent(this, bindings, config, ipc_bus, web_app.id));

        bindings.add_object(menu_bar);

        components.prepend(new AudioScrobblerComponent(this, bindings, master != null ? master.config : null, config, connection.session));
        components.prepend(new MPRISComponent(this, bindings, config));
        components.prepend(new HttpRemoteControl.Component(this, bindings, config, ipc_bus));
        components.prepend(new LyricsComponent(this, bindings, config));
        components.prepend(new DeveloperComponent(this, bindings, config));
        components.reverse();

        foreach (Component component in components) {
            component.setup(tiliado_paywall);
            debug("Component %s (%s) available=%s, enabled=%s", component.id, component.name,
                component.available.to_string(), component.enabled.to_string());
            component.notify["enabled"].connect_after(on_component_enabled_changed);
        }
        setup_sidebar();
    }

    private void setup_sidebar() {
        /* Components are activated asynchronously so we cannot be sure when all of them are activated and we can
         * unfreeze the sidebar. Let's wait 200 ms to see if there are any more pages to be added.*/
        if (setup_sidebar_timeout_id != 0) {
            Source.remove(setup_sidebar_timeout_id);
            setup_sidebar_timeout_id = 0;
        }
        unowned Sidebar sidebar = main_window.sidebar;
        if (sidebar.frozen) {
            setup_sidebar_timeout_id = Timeout.add(200, () => {
                setup_sidebar_timeout_id = 0;
                string? sidebar_page = config.get_string(ConfigKey.WINDOW_SIDEBAR_PAGE);
                if (sidebar_page != null && sidebar.has_page(sidebar_page)) {
                    sidebar.page = sidebar_page;
                }
                if (!sidebar.visible && config.get_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE)) {
                    sidebar.show();
                }
                sidebar.frozen = false;
                return false;
            });
        }
    }

    private void on_fatal_error(string title, string message, bool markup) {
        var dialog = new Drtgtk.ErrorDialog(
            title,
            message + "\n\nThe application has reached an inconsistent state and will quit for that reason.",
            markup);
        dialog.run();
        dialog.destroy();
    }

    private void on_show_error(string title, string message, bool markup) {
        var dialog = new Drtgtk.ErrorDialog(
            title,
            message + "\n\nThe application might not function properly.",
            markup);
        Idle.add(() => {
            dialog.run();
            dialog.destroy();
            return false;
        });
    }

    private void on_show_warning(string title, string message) {
        var info_bar = new Gtk.InfoBar();
        info_bar.show_close_button = true;
        var label = new Gtk.Label(Markup.printf_escaped("<span size='medium'><b>%s</b></span> %s", title, message));
        label.use_markup = true;
        label.vexpand = false;
        label.hexpand = true;
        label.halign = Gtk.Align.START;
        label.set_line_wrap(true);
        ((Gtk.Container) info_bar.get_content_area()).add(label);
        info_bar.response.connect(on_close_warning);
        info_bar.show_all();
        main_window.info_bars.add(info_bar);
    }

    private void on_info_bar_response(string id, int response) {
        switch (id) {
        case "theme-warning":
            switch (response) {
            case 0:
                do_preferences();
                break;
            case 1:
                show_uri("https://github.com/tiliado/nuvolaplayer/wiki/GTK-Themes");
                break;
            }
            break;
        case "feature-voting":
            switch (response) {
            case 0:
                show_uri("https://github.com/tiliado/nuvolaplayer/issues/678");
                break;
            case Gtk.ResponseType.CLOSE:
                config.set_bool("infobar.feature_voting_closed", true);
                break;
            }
            break;
        }
    }

    public bool show_info_bar(string id, Gtk.MessageType type, string text, string[]? buttons = null) {
        if (id in info_bars) {
            return false;
        }
        var info_bar = new Gtk.InfoBar();
        info_bar.set_message_type(type);
        info_bars[id] = info_bar;
        info_bar.show_close_button = true;
        var label = new Gtk.Label(text);
        label.use_markup = true;
        label.vexpand = false;
        label.hexpand = true;
        label.halign = Gtk.Align.START;
        label.set_line_wrap(true);
        ((Gtk.Container) info_bar.get_content_area()).add(label);
        if (buttons != null) {
            for (var i = 0; i < buttons.length; i++) {
                info_bar.add_button(buttons[i], i);
            }
        }
        info_bar.show_all();
        main_window.info_bars.add(info_bar);
        ulong handler_id = 0;
        handler_id = info_bar.response.connect((emitter, response_id) => {
            info_bar_response(id, response_id);
            if (response_id == Gtk.ResponseType.CLOSE) {
                emitter.disconnect(handler_id);
                ((Gtk.Container) emitter.get_parent()).remove(emitter);
                info_bars.remove(id);
                emitter.destroy();
            }
        });
        return true;
    }

    private void on_close_warning(Gtk.InfoBar info_bar, int response_id) {
        ((Gtk.Container) info_bar.get_parent()).remove(info_bar);
    }

    private bool on_window_state_event(Gdk.EventWindowState event) {
        bool m = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        config.set_bool(ConfigKey.WINDOW_MAXIMIZED, m);
        return false;
    }

    private void on_window_is_active_changed(Object o, ParamSpec p) {
        if (!main_window.is_active) {
            return;
        }

        if (ipc_bus.master != null) {
            try {
                Variant? response = ipc_bus.master.call_sync("/nuvola/core/runner-activated", new Variant("(s)", web_app.id));
                warn_if_fail(response.equal(new Variant.boolean(true)));
            } catch (GLib.Error e) {
                critical("Communication with master process failed: %s", e.message);
            }
        }
    }

    private bool on_configure_event(Gdk.EventConfigure event) {
        if (configure_event_cb_id != 0) {
            Source.remove(configure_event_cb_id);
        }
        configure_event_cb_id = Timeout.add(200, on_configure_event_cb);
        return false;
    }

    private bool on_configure_event_cb() {
        configure_event_cb_id = 0;
        if (!main_window.maximized) {
            int x;
            int y;
            int width;
            int height;
            main_window.get_position(out x, out y);
            main_window.get_size(out width, out height);
            config.set_int64(ConfigKey.WINDOW_X, (int64) x);
            config.set_int64(ConfigKey.WINDOW_Y, (int64) y);
            config.set_int64(ConfigKey.WINDOW_WIDTH, (int64) width);
            config.set_int64(ConfigKey.WINDOW_HEIGHT, (int64) height);
        }
        return false;
    }

    private void on_component_enabled_changed(GLib.Object object, ParamSpec param) {
        var component = object as Component;
        return_if_fail(component != null && web_engine != null);
        string signal_name = component.enabled ? "ComponentLoaded" : "ComponentUnloaded";
        var payload = new Variant("(sss)", signal_name, component.id, component.name);
        try {
            web_engine.call_function_sync("Nuvola.core.emit", ref payload);
        } catch (GLib.Error e) {
            warning("Communication with web engine failed: %s", e.message);
        }
        web_engine.web_worker.call_function.begin("Nuvola.core.emit", payload, false, (o, res) => {
            try {
                web_engine.web_worker.call_function.end(res, null);
            } catch (GLib.Error e) {
                warning("Communication with web worker failed: %s", e.message);
            }
        });
    }

    private void handle_get_metadata(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(web_app.to_variant());
    }

    private void handle_get_component_info(Drt.RpcRequest request) throws Drt.RpcError {
        string? id = request.pop_string();
        if (components != null) {
            foreach (unowned Component component in components) {
                if (id == component.id) {
                    var builder = new VariantBuilder(new VariantType("a{smv}"));
                    builder.add("{smv}", "name", new Variant.string(component.name));
                    builder.add("{smv}", "found", new Variant.boolean(true));
                    builder.add("{smv}", "loaded", new Variant.boolean(component.enabled));
                    builder.add("{smv}", "active", new Variant.boolean(component.active));
                    request.respond(builder.end());
                    return;
                }
            }
        }
        var builder = new VariantBuilder(new VariantType("a{smv}"));
        builder.add("{smv}", "name", new Variant.string(""));
        builder.add("{smv}", "found", new Variant.boolean(false));
        builder.add("{smv}", "loaded", new Variant.boolean(false));
        request.respond(builder.end());
    }

    private void handle_toggle_component_active(Drt.RpcRequest request) throws Drt.RpcError {
        string? id = request.pop_string();
        bool active = request.pop_bool();
        if (components != null) {
            foreach (unowned Component component in components) {
                if (id == component.id) {
                    request.respond(new Variant.boolean(component.toggle_active(active)));
                    return;
                }
            }
        }
        request.respond(new Variant.boolean(false));
    }

    private void handle_show_info_bar(Drt.RpcRequest request) throws Drt.RpcError {
        string? id = request.pop_string();
        int type = (int) request.pop_double();
        string? text = request.pop_string();
        if (type < 0 || type > 3) {
            throw new Drt.RpcError.INVALID_ARGUMENTS("Info bar type must be >= 0 and <= 3, %d received.", type);
        } else {
            request.respond(show_info_bar(id, (Gtk.MessageType) type, text));
        }
    }

    private void on_action_changed(Drtgtk.Action action, ParamSpec p) {
        if (web_engine == null || p.name != "enabled") {
            return;
        }
        var payload = new Variant("(ssb)", "ActionEnabledChanged", action.name, action.enabled);
        web_engine.web_worker.call_function.begin("Nuvola.actions.emit", payload, false, (o, res) => {
            try {
                web_engine.web_worker.call_function.end(res, null);
            } catch (GLib.Error e) {
                if (e is Drt.RpcError.NOT_READY) {
                    debug("Communication failed: %s", e.message);
                } else {
                    warning("Communication failed: %s", e.message);
                }
            }
        });
    }

    private void on_config_changed(string key, Variant? old_value) {
        switch (key) {
        case ConfigKey.SYSTEM_DECORATIONS:
            shell.client_side_decorations = !config.get_bool(ConfigKey.SYSTEM_DECORATIONS);
            break;
        case ConfigKey.DARK_THEME:
            Gtk.Settings.get_default().gtk_application_prefer_dark_theme = config.get_bool(ConfigKey.DARK_THEME);
            break;
        case ConfigKey.GTK_THEME:
            if (config.has_key(key) && config.get_string(key) == Drtgtk.DesktopShell.get_initial_gtk_theme()) {
                // Unset the value to track user's global theme.
                config.unset(ConfigKey.GTK_THEME);
            }
            break;
        }
        if (web_engine != null) {
            var payload = new Variant("(ss)", "ConfigChanged", key);
            try {
                web_engine.call_function_sync("Nuvola.config.emit", ref payload, false);
            } catch (GLib.Error e) {
                warning("WebEngine communication failed: %s", e.message);
            }
            if (web_engine.web_worker != null && web_engine.web_worker.ready) {
                payload = new Variant("(ss)", "ConfigChanged", key);
                web_engine.web_worker.call_function.begin("Nuvola.config.emit", payload, false, (o, res) => {
                    try {
                        web_engine.web_worker.call_function.end(res, null);
                    } catch (GLib.Error e) {
                        warning("WebWorker communication failed: %s", e.message);
                    }
                });
            }
        }
    }

    private void on_web_engine_notify(GLib.Object o, ParamSpec p) {
        switch (p.name) {
        case "can-go-forward":
            actions.get_action(Actions.GO_FORWARD).enabled = web_engine.can_go_forward;
            break;
        case "can-go-back":
            actions.get_action(Actions.GO_BACK).enabled = web_engine.can_go_back;
            break;
        case "is-loading":
            Drtgtk.HeaderBarTitle title_bar = main_window.headerbar_title;
            if (web_engine.is_loading) {
                var spinner = new Gtk.Spinner();
                spinner.start();
                spinner.show();
                title_bar.start_widget = spinner;
                title_bar.set_subtitle("loading...");
            } else {
                title_bar.start_widget = null;
                title_bar.set_subtitle(null);
            }
            break;
        }
    }

    private void on_can_quit(ref bool can_quit) {
        if (web_engine != null) {
            try {
                if (web_engine.web_worker.ready) {
                    can_quit = web_engine.web_worker.send_data_request_bool("QuitRequest", "approved", can_quit);
                } else {
                    debug("WebWorker not ready");
                }
            } catch (GLib.Error e) {
                warning("QuitRequest failed in web worker: %s", e.message);
            }
            try {

                if (web_engine.ready) {
                    can_quit = web_engine.send_data_request_bool("QuitRequest", "approved", can_quit);
                } else {
                    debug("WebEngine not ready");
                }
            } catch (GLib.Error e) {
                warning("QuitRequest failed in web engine: %s", e.message);
            }
        }
    }

    private void on_init_form(HashTable<string, Variant> values, Variant entries) {
        if (init_form != null) {
            main_window.overlay.remove(init_form);
            init_form = null;
        }

        try {
            init_form = Drtgtk.Form.create_from_spec(values, entries);
            init_form.check_toggles();
            init_form.expand = true;
            init_form.valign = init_form.halign = Gtk.Align.CENTER;
            init_form.show();
            var button = new Gtk.Button.with_label("OK");
            button.margin = 10;
            button.show();
            button.clicked.connect(on_init_form_button_clicked);
            init_form.attach_next_to(button, null, Gtk.PositionType.BOTTOM, 2, 1);
            main_window.grid.add(init_form);
            init_form.show();
        } catch (Drtgtk.FormError e) {
            show_error("Initialization form error",
                "Initialization form hasn't been shown because of malformed form specification: %s"
                .printf(e.message));
        }
    }

    private void on_init_form_button_clicked(Gtk.Button button) {
        button.clicked.disconnect(on_init_form_button_clicked);
        main_window.grid.remove(init_form);
        HashTable<string, Variant> new_values = init_form.get_values();
        init_form = null;

        foreach (unowned string key in new_values.get_keys()) {
            Variant? new_value = new_values.get(key);
            if (new_value == null) {
                critical("New values '%s'' not found", key);
            } else {
                config.set_value(key, new_value);
            }
        }

        web_engine.init_app_runner();
    }

    private void on_sidebar_visibility_changed(GLib.Object o, ParamSpec p) {
        bool visible = main_window.sidebar.visible;
        config.set_bool(ConfigKey.WINDOW_SIDEBAR_VISIBLE, visible);
        if (visible) {
            main_window.sidebar_position = (int) config.get_int64(ConfigKey.WINDOW_SIDEBAR_POS);
        }

        actions.get_action(Actions.TOGGLE_SIDEBAR).state = new Variant.boolean(visible);
    }

    private void on_sidebar_page_changed() {
        unowned Sidebar sidebar = main_window.sidebar;
        if (sidebar.visible) {
            string? page = sidebar.page;
            if (page != null) {
                config.set_string(ConfigKey.WINDOW_SIDEBAR_PAGE, page);
            }
        }
    }

    private void on_sidebar_page_added(Sidebar sidebar, string name, string label, Gtk.Widget child, bool show) {
        actions.get_action(Actions.TOGGLE_SIDEBAR).enabled = !sidebar.is_empty();
        setup_sidebar();
    }

    private void on_sidebar_page_removed(Sidebar sidebar, Gtk.Widget child) {
        actions.get_action(Actions.TOGGLE_SIDEBAR).enabled = !sidebar.is_empty();
    }

    private void on_show_alert_dialog(ref bool handled, string text) {
        main_window.show_overlay_alert(text);
        handled = true;
    }

    private void on_show_script_dialog(ScriptDialogModel model) {
        var dialog = new ScriptOverlayDialog(model);
        model.handled = true;
        if (dialog.snapshot != null) {
            main_window.overlay.add_overlay(dialog.snapshot);
        }
        main_window.add_overlay_widget(dialog);
        main_window.present();
        dialog.reveal();
    }

    private void on_window_removed(Gtk.Window window) {
        if (window == main_window) {
            quit_mainloop();
        }
    }
}

} // namespace Nuvola
