/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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
	static string? app_id = null;
	static string? apps_dir = null;
	static string? log_file = null;
	
	public static const OptionEntry[] options =
	{
		{ "app-id", 'a', 0, OptionArg.STRING, ref app_id, "Web app to run, e.g. \"happy_songs\" for Happy Songs web app.", "ID" },
		{ "apps-dir", 'A', 0, GLib.OptionArg.FILENAME, ref Args.apps_dir, "Search for web app integrations only in directory DIR and disable service management.", "DIR" },
		{ "verbose", 'v', 0, OptionArg.NONE, ref Args.verbose, "Print informational messages", null },
		{ "debug", 'D', 0, OptionArg.NONE, ref Args.debug, "Print debugging messages", null },
		{ "version", 'V', 0, OptionArg.NONE, ref Args.version, "Print version and exit", null },
		{ "log-file", 'L', 0, OptionArg.FILENAME, ref Args.log_file, "Log to file", "FILE" },
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
		stdout.printf("Revision %s\n", Nuvola.get_revision());
		stdout.printf("Diorite %s\n", Drt.get_version());
		stdout.printf("WebKitGTK %u.%u.%u\n", WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version());
		stdout.printf("libsoup %u.%u.%u\n", Soup.get_major_version(), Soup.get_minor_version(), Soup.get_micro_version());
		return 0;
	}
	
	var local_only_args = false;
	FileStream? log = null;
	if (Args.log_file != null)
	{
		local_only_args = true;
		log = FileStream.open(Args.log_file, "w");
		if (log == null)
		{
			stderr.printf("Cannot open log file '%s' for writting.\n", Args.log_file);
			return 1;
		}
	}
	
	Diorite.Logger.init(log != null ? log : stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
	 : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING), true,
	 "Master");
	
	/* Disable compositing mode in WebKitGTK < 2.13.4 as some websites may crash system with it:
	 * https://bugs.webkit.org/show_bug.cgi?id=126122
	 * https://github.com/tiliado/nuvolaplayer/issues/245
	 * 
	 * Note that WEBKIT_FORCE_COMPOSITING_MODE is honoured since WebKitGTK 2.10.5:
	 * https://trac.webkit.org/wiki/EnvironmentVariables
	 */
	uint webkit_version = WebKit.get_major_version() * 10000 + WebKit.get_minor_version() * 100 + WebKit.get_micro_version();
	if (webkit_version < 21304)
	{
		Environment.set_variable("WEBKIT_DISABLE_COMPOSITING_MODE", "1", true);
		debug("Compositing mode disabled because of WebKitGTK < 2.13.4");
	}
	
	if (Environment.get_variable("NUVOLA_TEST_ABORT") == "master")
		error("Master abort requested.");
	
	if (Args.apps_dir == null)
		Args.apps_dir = Environment.get_variable("NUVOLA_WEB_APPS_DIR");
	
	var storage = new Diorite.XdgStorage.for_project(Nuvola.get_app_id());
	var web_apps_storage = storage.get_child("web_apps");
	
	File? packages_dir = null;
		
	WebAppRegistry web_app_reg;
	if (Args.apps_dir != null && Args.apps_dir != "")
	{
		local_only_args = true;
		web_app_reg = new WebAppRegistry(File.new_for_path(Args.apps_dir), {}, false, packages_dir);
	}
	else
	{
		#if FLATPAK
		packages_dir = File.new_for_path("/var/lib/flatpak/exports/nuvola");
		#endif
		web_app_reg = new WebAppRegistry(web_apps_storage.user_data_dir, web_apps_storage.data_dirs, true, packages_dir);
	}
	
	string[] exec_cmd = {};
	
	#if LINUX
	var gdb_server = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER");
	if (gdb_server != null)
	{
		exec_cmd += "/usr/bin/gdbserver";
		exec_cmd += gdb_server ;
	}
	#endif
	
	exec_cmd += Nuvola.get_app_runner_path();
	
	if (Args.debug)
	{
		local_only_args = true;
		exec_cmd += "-D";
	}
	else if (Args.verbose)
	{
		local_only_args = true;
		exec_cmd += "-v";
	}
	
	var controller = new MasterController(storage, web_app_reg, (owned) exec_cmd, Args.debug);
	var controller_args = Args.app_id != null ? new string[]{args[0], "-a", Args.app_id} : new string[]{args[0]};
	for (var i = 1; i < args.length; i++)
		controller_args += args[i];
	var result = controller.run(controller_args);
	
	if (controller.is_remote)
	{
		message("%s instance is already running and will be activated.", Nuvola.get_app_name());
		if (local_only_args)
			warning(
				"Some command line parameters (-D, -v, -A, -L) are ignored because they apply only to a new instance."
				+ " You might want to close all %s instances and run it again with your parameters.",
				Nuvola.get_app_name());
	}
	return result;
}

} // namespace Nuvola

