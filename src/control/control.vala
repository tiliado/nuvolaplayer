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

static bool opt_debug = false;
static bool opt_verbose = false;
static bool opt_version;
static string? opt_app;
static string? opt_log_file;
[CCode (array_length = false, array_null_terminated = true)]
static string?[] opt_command;

public const OptionEntry[] opt_main_options = {
    { "app", 'a', 0, GLib.OptionArg.FILENAME, ref opt_app, "Web app to control.", "ID" },
    { "verbose", 'v', 0, OptionArg.NONE, ref opt_verbose, "Print informational messages", null },
    { "debug", 'D', 0, OptionArg.NONE, ref opt_debug, "Print debugging messages", null },
    { "version", 'V', 0, OptionArg.NONE, ref opt_version, "Print version and exit", null },
    { "log-file", 'L', 0, OptionArg.FILENAME, ref opt_log_file, "Log to file", "FILE" },
    { "", 0, 0, GLib.OptionArg.STRING_ARRAY, ref opt_command, "Command.", "COMMAND PARAMS..."},
    { null }
};


[PrintfFormat]
private static int quit(int code, string format, ...) {
    stderr.vprintf(format, va_list());
    return code;
}

/*
TODO: Nuvola Player 2 interface
status    print current status (playback state, song info)
play      start playback
pause     pause playback
toggle    toggle play/pause
next      skip to next song
prev      skip to previous song
raise     raise Nuvola Player window
quit      quit Nuvola Player
 */
const string DESCRIPTION = """Commands:

  list-actions
    - list available actions

  action NAME [STATE]
    - invoke action with name NAME
    - STATE parameter is used to select option of a radio action

  action-state NAME
    - get state of radio or toggle action with name NAME
    - does nothing for simple actions
    - you can set state actions with `action` command

  track-info [KEY]
   - prints track information
   - KEY can be 'all' (default), 'title', 'artist', 'album', 'state',
     'artwork_location', 'artwork_file' or 'rating'.
""";

public int main(string[] args) {
    try {
        var opt_context = new OptionContext("- Control %s".printf(Nuvola.get_app_name()));
        opt_context.set_help_enabled(true);
        opt_context.add_main_entries(opt_main_options, null);
        opt_context.set_ignore_unknown_options(false);
        opt_context.set_description(DESCRIPTION);
        opt_context.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("Error: Option parsing failed: %s\n", e.message);
        return 1;
    }

    if (opt_version) {
        stdout.printf("%s %s\n", Nuvola.get_app_name(), Nuvola.get_version());
        return 0;
    }

    FileStream? log = null;
    if (opt_log_file != null) {
        log = FileStream.open(opt_log_file, "w");
        if (log == null) {
            stderr.printf("Error: Cannot open log file '%s' for writing.\n", opt_log_file);
            return 1;
        }
    }

    Drt.Logger.init(log != null ? log : stderr, opt_debug ? GLib.LogLevelFlags.LEVEL_DEBUG
        : (opt_verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
        true, "Control");

    if (opt_command.length < 1) {
        #if FLATPAK
        // It might happen that nuvolactl is launched from the Nuvola Apps Service entry in GNOME Software.
        stderr.printf("Error: No command specified. Type `%s --help` for help.\nLaunching service info...\n", args[0]);
        try {
            Process.spawn_sync(null, {"nuvolaserviceinfo", null}, null, SpawnFlags.SEARCH_PATH, null, null, null, null);
        } catch (GLib.Error e) {
            warning("Failed to spawn nuvolaserviceinfo: %s", e.message);
        }
        return 1;
        #else
        return quit(1, "Error: No command specified. Type `%s --help` for help.\n", args[0]);
        #endif
    }

    if (opt_app == null) {
        try {
            var master = new Drt.RpcChannel.from_name(1, build_master_ipc_id(), null, null, 500);

            Variant? response = master.call_sync("/nuvola/core/get_top_runner", null);
            Drt.Rpc.check_type_string(response, "ms");
            response.get("ms", out opt_app);

            if (opt_app == null || opt_app == "") {
                return quit(1, "Error: No %s instance is running.\n", Nuvola.get_app_name());
            }

            message("Using '%s' as web app id.", opt_app);
        } catch (GLib.Error e) {
            return quit(2, "Error: Communication with %s master instance failed: %s\n", Nuvola.get_app_name(), e.message);
        }
    }

    Drt.RpcChannel client;
    GLib.Socket? socket = null;
    try {
        string uid = WebApp.build_uid_from_app_id(opt_app, Nuvola.get_dbus_id());
        string path = "/" + uid.replace(".", "/");
        AppDbusIfce app_api = Bus.get_proxy_sync<AppDbusIfce>(
            BusType.SESSION, uid, path,
            DBusProxyFlags.DO_NOT_CONNECT_SIGNALS|DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
        app_api.get_connection(out socket);
    } catch (GLib.Error e) {
        return quit(2, "Error: Failed to connect to %s instance for %s. %s\n", Nuvola.get_app_name(), opt_app, e.message);
    }
    if (socket == null) {
        return quit(2, "Error: Failed to connect to %s instance for %s. Null socket.\n", Nuvola.get_app_name(), opt_app);
    }

    try {
        client = new Drt.RpcChannel(2, new Drt.SocketChannel.from_socket(2, socket, 500), null, null);
    } catch (GLib.Error e) {
        return quit(2, "Error: Failed to connect to %s instance for %s. %s\n", Nuvola.get_app_name(), opt_app, e.message);
    }


    string command = opt_command[0];
    var control = new Control(client);
    try {
        switch (command) {
        case "action":
            if (opt_command.length < 2) {
                return quit(1, "Error: No action specified.\n");
            }
            return control.activate_action(opt_command[1], opt_command.length == 2 ? null : opt_command[2]);
        case "list-actions":
            if (opt_command.length > 1) {
                return quit(1, "Error: Too many arguments.\n");
            }
            return control.list_actions();
        case "action-state":
            if (opt_command.length < 2) {
                return quit(1, "Error: No action specified.\n");
            }
            return control.action_state(opt_command[1]);
        case "track-info":
            if (opt_command.length > 2) {
                return quit(1, "Error: Too many arguments.\n");
            }
            return control.track_info(opt_command.length == 2 ? opt_command[1] : null);
        case "api-master":
            if (opt_command.length < 2) {
                return quit(1, "Error: No API method specified.\n");
            }
            try {
                var master = new Drt.RpcChannel.from_name(1, build_master_ipc_id(), null, null, 500);
                return call_api_method(master, opt_command, 1);
            } catch (GLib.Error e) {
                return quit(2, "Error: Communication with %s master instance failed: %s\n", Nuvola.get_app_name(), e.message);
            }
        case "api-app":
            if (opt_command.length < 2) {
                return quit(1, "Error: No API method specified.\n");
            }
            try {
                return call_api_method(client, opt_command, 1);
            } catch (GLib.Error e) {
                return quit(2, "Error: Communication with %s instance for %s failed. %s\n", Nuvola.get_app_name(), opt_app, e.message);
            }
        default:
            return quit(1, "Error: Unknown command '%s'.\n", command);
        }
    } catch (GLib.Error e) {
        return quit(2, "Error: Communication with %s instance failed: %s\n", Nuvola.get_app_name(), e.message);
    }
}

private int call_api_method(Drt.RpcChannel connection, string[] args, int offset) throws GLib.Error {
    var builder = new VariantBuilder(new VariantType("a{smv}"));
    for (int i = offset + 1; i < args.length; i++) {
        string[] parts = args[i].split("=", 2);
        if (parts.length != 2) {
            stderr.printf("Invalid argument %d - must be in format 'key=value': %s\n", i, args[i]);
            return 1;
        }
        unowned string key = parts[0];
        if (Drt.String.is_empty(key)) {
            stderr.printf("Invalid argument %d - must be in format 'key=value': %s\n", i, args[i]);
            return 1;
        }
        Variant? val = Drt.VariantUtils.parse_typed_value(parts[1]);
        builder.add("{smv}", key, val);
    }
    Variant? response = connection.call_sync(args[offset], builder.end());
    if (response != null) {
        Json.Node node = Json.gvariant_serialize(response);
        var generator = new Json.Generator();
        generator.pretty = true;
        generator.set_root(node);
        string data = generator.to_data(null);
        stdout.printf("%s\n", data);
    }
    return 0;
}

class Control {
    private Drt.RpcChannel conn;

    public Control(Drt.RpcChannel conn) {
        this.conn = conn;
    }

    public int list_actions() throws GLib.Error {
        Variant? response = conn.call_sync("/nuvola/actions/list-groups", null);
        stdout.printf("Available actions\n\nFormat: NAME (is enabled?) - label\n");
        VariantIter iter = response.iterator();
        string group_name = null;
        while (iter.next("s", out group_name)) {
            stdout.printf("\nGroup: %s\n\n", group_name);
            Variant? actions = conn.call_sync("/nuvola/actions/list-group-actions", new Variant("(s)", group_name));
            Variant action = null;
            VariantIter actions_iter = actions.iterator();
            while (actions_iter.next("@*", out action)) {
                string name = null;
                string label = null;
                bool enabled = false;
                Variant options = null;
                assert(action.lookup("name", "s", out name));
                assert(action.lookup("label", "s", out label));
                assert(action.lookup("enabled", "b", out enabled));
                if (action.lookup("options", "@*", out options)) {
                    stdout.printf(" *  %s (%s) - %s\n", name, enabled ? "enabled" : "disabled", "invoke with following parameters:");
                    Variant option = null;
                    VariantIter options_iter = options.iterator();
                    while (options_iter.next("@*", out option)) {
                        Variant parameter = null;
                        assert(option.lookup("param", "@*", out parameter));
                        assert(option.lookup("label", "s", out label));
                        stdout.printf("    %s %s - %s\n", name, parameter.print(false), label != "" ? label : "(No label specified.)");
                    }
                } else {
                    stdout.printf(" *  %s (%s) - %s\n", name, enabled ? "enabled" : "disabled", label != "" ? label : "(No label specified.)");
                }
            }
        }
        return 0;
    }

    public int activate_action(string name, string? parameter_str) throws GLib.Error {
        Variant parameter;
        try {
            parameter =  parameter_str == null
            ? new Variant.maybe(VariantType.BYTE, null)
            :  Variant.parse(null, parameter_str);

        } catch (VariantParseError e) {
            return quit(1,
                "Failed to parse Variant from string %s: %s\n\n"
                + "See https://developer.gnome.org/glib/stable/gvariant-text.html for format specification.\n",
                parameter_str, e.message);
        }

        Variant? response = conn.call_sync("/nuvola/actions/activate",
            new Variant.tuple({new Variant.string(name), parameter}));
        bool handled = false;
        if (!Drt.VariantUtils.get_bool(response, out handled)) {
            return quit(2, "Got invalid response from %s instance: %s\n", Nuvola.get_app_name(),
                Drt.VariantUtils.print(response));
        }
        if (!handled) {
            return quit(3, "%s instance doesn't understand requested action '%s'.\n", Nuvola.get_app_name(), name);
        }

        message("Action %s %s was successful.", name, parameter_str);
        return 0;
    }

    public int action_state(string name) throws GLib.Error {
        Variant? response = conn.call_sync("/nuvola/actions/get-state", new Variant("(s)", name));
        if (response != null) {
            stdout.printf("%s\n", response.print(false));
        }
        return 0;
    }

    public int track_info(string? key=null) throws GLib.Error {
        Variant? response = conn.call_sync("/nuvola/mediaplayer/track-info", null);
        string? title;
        Drt.VariantUtils.get_maybe_string_item(response, "title", out title);
        string? artist;
        Drt.VariantUtils.get_maybe_string_item(response, "artist", out artist);
        string? album;
        Drt.VariantUtils.get_maybe_string_item(response, "album", out album);
        string? state;
        Drt.VariantUtils.get_maybe_string_item(response, "state", out state);
        string? artwork_location;
        Drt.VariantUtils.get_maybe_string_item(response, "artworkLocation", out artwork_location);
        string? artwork_file;
        Drt.VariantUtils.get_maybe_string_item(response, "artworkFile", out artwork_file);
        double rating;
        if (!Drt.VariantUtils.get_double_item(response, "rating", out rating)) {
            rating = 0.0;
        }

        if (key == null || key == "all") {
            if (title != null) {
                stdout.printf("Title: %s\n", title);
            }
            if (artist != null ) {
                stdout.printf("Artist: %s\n", artist);
            }
            if (album != null ) {
                stdout.printf("Album: %s\n", album);
            }
            if (state != null ) {
                stdout.printf("State: %s\n", state);
            }
            if (artwork_location != null ) {
                stdout.printf("Artwork location: %s\n", artwork_location);
            }
            if (artwork_file != null ) {
                stdout.printf("Artwork file: %s\n", artwork_file);
            }
            if (rating != 0.0 ) {
                stdout.printf("Rating: %s\n", rating.to_string());
            }
        } else {
            switch (key) {
            case "title":
                if (title != null) {
                    stdout.printf("%s\n", title);
                }
                break;
            case "artist":
                if (artist != null) {
                    stdout.printf("%s\n", artist);
                }
                break;
            case "album":
                if (album != null) {
                    stdout.printf("%s\n", album);
                }
                break;
            case "state":
                if (state != null) {
                    stdout.printf("%s\n", state);
                }
                break;
            case "artwork_location":
                if (artwork_location != null) {
                    stdout.printf("%s\n", artwork_location);
                }
                break;
            case "artwork_file":
                if (artwork_file != null) {
                    stdout.printf("%s\n", artwork_file);
                }
                break;
            case "rating":
                if (rating != 0.0 ) {
                    stdout.printf("Rating: %s\n", rating.to_string());
                }
                break;
            default:
                return quit(3, "Unknown key '%s'.\n", key);
            }
        }
        return 0;
    }
}

} // namespace Nuvola

