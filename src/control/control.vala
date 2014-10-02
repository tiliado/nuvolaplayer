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

struct Args
{
	static bool debug = false;
	static bool verbose = false;
	static bool version;
	static string? app;
	static string? log_file;
	[CCode (array_length = false, array_null_terminated = true)]
	static string?[] command;
	
	public static const OptionEntry[] main_options =
	{
		{ "app", 'a', 0, GLib.OptionArg.FILENAME, ref Args.app, "Web app to control.", "ID" },
		{ "verbose", 'v', 0, OptionArg.NONE, ref Args.verbose, "Print informational messages", null },
		{ "debug", 'D', 0, OptionArg.NONE, ref Args.debug, "Print debugging messages", null },
		{ "version", 'V', 0, OptionArg.NONE, ref Args.version, "Print version and exit", null },
		{ "log-file", 'L', 0, OptionArg.FILENAME, ref Args.log_file, "Log to file", "FILE" },
		{ "", 0, 0, GLib.OptionArg.STRING_ARRAY, ref Args.command, "Command.", "COMMAND PARAMS..."},
		{ null }
	};
}

[PrintfFormat]
private static int quit(int code, string format, ...)
{
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

  action NAME [PARAMETER]
    - invoke action with name NAME and optional parameter PARAMETER
""";

public int main(string[] args)
{
	try
	{
		var opt_context = new OptionContext("- %s".printf(Nuvola.get_app_name()));
		opt_context.set_help_enabled(true);
		opt_context.add_main_entries(Args.main_options, null);
		opt_context.set_ignore_unknown_options(false);
		opt_context.set_description(DESCRIPTION);
		opt_context.parse(ref args);
	}
	catch (OptionError e)
	{
		stderr.printf("Error: Option parsing failed: %s\n", e.message);
		return 1;
	}
	
	if (Args.version)
	{
		stdout.printf("%s %s\n", Nuvola.get_app_name(), Nuvola.get_version());
		return 0;
	}
	
	if (Args.app == null)
		return quit(1, "Error: No app specified.\n");
	
	FileStream? log = null;
	if (Args.log_file != null)
	{
		log = FileStream.open(Args.log_file, "w");
		if (log == null)
		{
			stderr.printf("Error: Cannot open log file '%s' for writing.\n", Args.log_file);
			return 1;
		}
	}
	
	Diorite.Logger.init(log != null ? log : stderr, Args.debug ? GLib.LogLevelFlags.LEVEL_DEBUG
	  : (Args.verbose ? GLib.LogLevelFlags.LEVEL_INFO: GLib.LogLevelFlags.LEVEL_WARNING),
	  "Control");

	if (Args.command.length < 1)
		return quit(1, "Error: No command specified.\n");
	
	var client = new Diorite.Ipc.MessageClient(build_ui_runner_ipc_id(Args.app), 500);
	if (!client.wait_for_echo(500))
		return quit(2, "Error: Failed to connect to %s instance for %s.\n", Nuvola.get_app_name(), Args.app);
	
	var command = Args.command[0];
	var control = new Control(client);
	try
	{
		switch (command)
		{
		case "action":
			if (Args.command.length < 2)
				return quit(1, "Error: No action specified.\n");
			
			return control.activate_action(Args.command[1], Args.command.length == 2 ? null : Args.command[2]);
		default:
			return quit(1, "Error: Unknown command '%s'.\n", command);
		}
	}
	catch (Diorite.Ipc.MessageError e)
	{
		return quit(2, "Error: Communication with %s instance failed: %s\n", Nuvola.get_app_name(), e.message);
	}
	
	return 0;
}

class Control
{
	private Diorite.Ipc.MessageClient conn;
	
	public Control(Diorite.Ipc.MessageClient conn)
	{
		this.conn = conn;
	}
	
	public int activate_action(string name, string? parameter_str) throws Diorite.Ipc.MessageError
	{
		Variant parameter;
		try
		{
			parameter =  parameter_str == null
			? new Variant.maybe(VariantType.BYTE, null)
			:  Variant.parse(null, parameter_str);
			
		}
		catch (VariantParseError e)
		{
			return quit(1,
				"Failed to parse Variant from string %s: %s\n\n"
				+ "See https://developer.gnome.org/glib/stable/gvariant-text.html for format specification.\n",
				parameter_str, e.message);
		}
		
		var response = conn.send_message("Nuvola.Actions.activate",
			new Variant.tuple({new Variant.string(name), parameter}));
		bool handled = false;
		if (!Diorite.variant_bool(response, ref handled))
			return quit(2, "Got invalid response from %s instance: %s\n", Nuvola.get_app_name(),
				response == null ? "null" : response.print(true));
		if (!handled)
			return quit(3, "%s instance doesn't understand requested action '%s'.\n", Nuvola.get_app_name(), name);
		
		message("Action %s %s was successful.", name, parameter_str);
		return 0;
	}
}

} // namespace Nuvola

