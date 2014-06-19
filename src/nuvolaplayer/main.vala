/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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
	static string? apps_dir = null;
	static string? log_file = null;
	
	public static const OptionEntry[] options =
	{
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
	try
	{
		var opt_context = new OptionContext("- %s".printf(Nuvola.get_display_name()));
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
		stdout.printf("%s %s\n", Nuvola.get_display_name(), Nuvola.get_version());
		return 0;
	}
	
	FileStream? log = null;
	if (Args.log_file != null)
	{
		log = FileStream.open(Args.log_file, "w");
		if (log == null)
		{
			stderr.printf("Cannot open log file '%s' for writting.\n", Args.log_file);
			return 1;
		}
	}
	
	Diorite.Logger.init(log != null ? log : stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
	 : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
	 "Master");
	
	var storage = new Diorite.XdgStorage.for_project(Nuvola.get_appname());
	var web_apps_storage = storage.get_child("web_apps");
	var web_app_reg = Args.apps_dir != null && Args.apps_dir != ""
	? new WebAppRegistry.with_data_path(web_apps_storage, Args.apps_dir)
	: new WebAppRegistry(web_apps_storage, true);
	
	
	string[] exec_cmd = {};
	
	#if LINUX
	var gdb_server = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER");
	if (gdb_server != null)
	{
		exec_cmd += "/usr/bin/gdbserver";
		exec_cmd += gdb_server ;
	}
	#endif
	
	exec_cmd += Nuvola.get_ui_runner_path();
	
	if (Args.debug)
		exec_cmd += "-D";
	else if (Args.verbose)
		exec_cmd += "-v";
	if (Args.apps_dir != null && Args.apps_dir != "")
	{
		exec_cmd += "-A";
		exec_cmd += Args.apps_dir;
	}
	
	exec_cmd += "-a";
	var controller = new MasterController(storage, web_app_reg, (owned) exec_cmd);
	return controller.run(args);
}

} // namespace Nuvola

