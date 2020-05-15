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

static bool opt_debug;
static bool opt_verbose;
static bool opt_version;
#if !FLATPAK || !NUVOLA_RUNTIME
static string? opt_apps_dir = null;
#endif

public const OptionEntry[] opt_options = {
    #if !FLATPAK || !NUVOLA_RUNTIME
    { "apps-dir", 'A', 0, GLib.OptionArg.FILENAME, ref opt_apps_dir, "Search for web app integrations only in directory DIR and disable service management.", "DIR" },
    #endif
    { "verbose", 'v', 0, OptionArg.NONE, ref opt_verbose, "Print informational messages", null },
    { "debug", 'D', 0, OptionArg.NONE, ref opt_debug, "Print debugging messages", null },
    { "version", 'V', 0, OptionArg.NONE, ref opt_version, "Print version and exit", null },
    { null }
};


public int main(string[] args) {
    /* We are not ready for Wayland yet.
     * https://github.com/tiliado/nuvolaplayer/issues/181
     * https://github.com/tiliado/nuvolaplayer/issues/240
     */
    Environment.set_variable("GDK_BACKEND", "x11", true);

    try {
        var opt_context = new OptionContext("- %s".printf(Nuvola.get_app_name()));
        opt_context.set_help_enabled(true);
        opt_context.add_main_entries(opt_options, null);
        opt_context.set_ignore_unknown_options(true);
        opt_context.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("option parsing failed: %s\n", e.message);
        return 1;
    }

    if (opt_version) {
        print_version_info(stdout, null);
        return 0;
    }

    var local_only_args = false;
    Drt.Logger.init(stderr, opt_debug ? GLib.LogLevelFlags.LEVEL_DEBUG
        : (opt_verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING), true,
        "Master");

    if (Environment.get_variable("NUVOLA_TEST_ABORT") == "master") {
        error("Master abort requested.");
    }

    WebAppRegistry? web_app_reg = null;
    var storage = new Drt.XdgStorage.for_project(Nuvola.get_app_id());
    move_old_xdg_dirs(new Drt.XdgStorage.for_project(Nuvola.get_old_id()), storage);

    #if !FLATPAK || !NUVOLA_RUNTIME
    if (opt_apps_dir == null) {
        opt_apps_dir = Environment.get_variable("NUVOLA_WEB_APPS_DIR");
    }

    if (opt_apps_dir != null && opt_apps_dir != "") {
        local_only_args = true;
        web_app_reg = new WebAppRegistry(File.new_for_path(opt_apps_dir), {});
    } else {
        Drt.Storage web_apps_storage = storage.get_child("web_apps");
        web_app_reg = new WebAppRegistry(web_apps_storage.user_data_dir, web_apps_storage.data_dirs());
    }
    #endif

    string[] exec_cmd = {};
    string? gdb_server = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER");
    if (gdb_server != null) {
        exec_cmd += "/usr/bin/gdbserver";
        exec_cmd += gdb_server ;
    }

    exec_cmd += Nuvola.get_app_runner_path();
    if (opt_debug) {
        local_only_args = true;
        exec_cmd += "-D";
    } else if (opt_verbose) {
        local_only_args = true;
        exec_cmd += "-v";
    }

    var controller = new MasterController(storage, web_app_reg, (owned) exec_cmd, opt_debug);
    var controller_args = new string[] {args[0]};
    for (var i = 1; i < args.length; i++) {
        controller_args += args[i];
    }
    int result = controller.run(controller_args);

    if (controller.is_registered && controller.is_remote) {
        message("%s instance is already running and will be activated.", Nuvola.get_app_name());
        if (local_only_args) {
            warning(
                "Some command line parameters (-D, -v, -A, -L) are ignored because they apply only to a new instance."
                + " You might want to close all %s instances and run it again with your parameters.",
                Nuvola.get_app_name());
        }
    }
    return result;
}

} // namespace Nuvola

