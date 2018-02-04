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

/**
 * Struct containing command line arguments. Check Args.options for their meaning.
 */
struct Args {
    static bool debug;
    static bool verbose;
    static bool version;
    static string? app_dir;

    public const OptionEntry[] options = {
        { "app-dir", 'a', 0, GLib.OptionArg.FILENAME, ref Args.app_dir, "Web app to run.", "DIR" },
        { "verbose", 'v', 0, OptionArg.NONE, ref Args.verbose, "Print informational messages", null },
        { "debug", 'D', 0, OptionArg.NONE, ref Args.debug, "Print debugging messages", null },
        { "version", 'V', 0, OptionArg.NONE, ref Args.version, "Print version and exit", null },
        { null }
    };
}

public int main(string[] args) {
    try {
        var opt_context = new OptionContext("- %s".printf(Nuvola.get_app_name()));
        opt_context.set_help_enabled(true);
        opt_context.add_main_entries(Args.options, null);
        opt_context.set_ignore_unknown_options(true);
        opt_context.parse(ref args);
    }
    catch (OptionError e) {
        stderr.printf("option parsing failed: %s\n", e.message);
        return 1;
    }

    if (Args.app_dir == null) {
        Args.app_dir = ".";
    }

    Drt.Logger.init(stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
        : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
        true, "Runner");

    if (Environment.get_variable("NUVOLA_TEST_ABORT") == "runner") {
        error("App runner abort requested.");
    }

    File app_dir = File.new_for_path(Args.app_dir);
    if (Args.version) {
        return Nuvola.Startup.print_web_app_version(stdout, app_dir);
    }

    try {
        return Nuvola.Startup.run_web_app_with_dbus_handshake(app_dir, args);
    }
    catch (WebAppError e) {
        stderr.puts("Failed to load web app!\n");
        stderr.printf("Dir: %s\n", Args.app_dir);
        stderr.printf("Error: %s\n", e.message);
        return 1;
    }
}

} // namespace Nuvola

