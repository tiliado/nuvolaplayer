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

/**
 * Struct containing command line arguments. Check Args.options for their meaning.
 */
struct Args
{
	static bool debug;
	static bool verbose;
	static bool version;
	static string? app_dir;
	static bool nuvola_dbus;
	
	public const OptionEntry[] options =
	{
		{ "dbus", 0, 0, OptionArg.NONE, ref Args.nuvola_dbus, "Connect to Nuvola via DBus", null },
		{ "app-dir", 'a', 0, GLib.OptionArg.FILENAME, ref Args.app_dir, "Web app to run.", "DIR" },
		{ "verbose", 'v', 0, OptionArg.NONE, ref Args.verbose, "Print informational messages", null },
		{ "debug", 'D', 0, OptionArg.NONE, ref Args.debug, "Print debugging messages", null },
		{ "version", 'V', 0, OptionArg.NONE, ref Args.version, "Print version and exit", null },
		{ null }
	};
}

public int main(string[] args)
{
	/* We are not ready for Wayland yet.
	 * https://github.com/tiliado/nuvolaplayer/issues/181
	 * https://github.com/tiliado/nuvolaplayer/issues/240
	 */
	Environment.set_variable("GDK_BACKEND", "x11", true);
	try
	{
		var opt_context = new OptionContext("- %s".printf(Nuvola.get_app_name()));
		opt_context.set_help_enabled(true);
		opt_context.add_main_entries(Args.options, null);
		opt_context.set_ignore_unknown_options(true);
		opt_context.parse(ref args);
	}
	catch (OptionError e)
	{
		stderr.printf("option parsing failed: %s\n", e.message);
		return 1;
	}
	
	if (Args.version)
	{
		stdout.printf("%s %s\n", Nuvola.get_app_name(), Nuvola.get_version());
		return 0;
	}
	
	if (Args.app_dir == null)
	{
		stderr.printf("No app specified.");
		return 1;
	}
	
	Diorite.Logger.init(stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
	  : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
	  true, "Runner");
	
	if (Environment.get_variable("NUVOLA_TEST_ABORT") == "runner")
		error("App runner abort requested.");
	
	// Init GTK early to have be able to use Gtk.IconTheme stuff
	string[] empty_argv = {};
	unowned string[] unowned_empty_argv = empty_argv;
	Gtk.init(ref unowned_empty_argv);
	
	try
	{
		var app_dir = File.new_for_path(Args.app_dir);
		var web_app = WebAppMeta.load_from_dir(app_dir);
		#if !FLATPAK
		web_app.removable = false;
		if (!web_app.has_desktop_launcher)
		{
			warning(
				"The %s script doesn't provide a desktop file. It might not function properly."
				+ " Ask the maintainer to switch to the Nuvola SDK "
				+ "<https://github.com/tiliado/nuvolasdk> and build it with `./configure --with-desktop-launcher`.",
				web_app.name);
		}
		#endif
		var storage = new Diorite.XdgStorage.for_project(Nuvola.get_app_id());
		var app_storage = new WebAppStorage(
		  storage.user_config_dir.get_child(WEB_APP_DATA_DIR).get_child(web_app.id),
		  storage.user_data_dir.get_child(WEB_APP_DATA_DIR).get_child(web_app.id),
		  storage.user_cache_dir.get_child(WEB_APP_DATA_DIR).get_child(web_app.id));
		
		var api_token = !Args.nuvola_dbus ? stdin.read_line() : null;
		var controller = new AppRunnerController(storage, web_app, app_storage, api_token, Args.nuvola_dbus);
		return controller.run(args);
	}
	catch (WebAppError e)
	{
		warning("Failed to load web app from '%s'. %s", Args.app_dir, e.message);
		return 1;
	}
}

} // namespace Nuvola

