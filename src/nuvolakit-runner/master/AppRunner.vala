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

public abstract class AppRunner : GLib.Object
{
	protected static bool gdb = false;
	public string app_id {get; private set;}
	public bool connected {get{ return channel != null;}}
	public bool running {get; protected set; default = false;}
	protected GenericSet<string> capatibilities;
	protected Drt.ApiChannel channel = null;
	
	static construct
	{
		gdb = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER") != null;
	}
	
	public AppRunner(string app_id, string api_token) throws GLib.Error
	{
		this.app_id = app_id;
		this.capatibilities = new GenericSet<string>(str_hash, str_equal);
	}
	
	public signal void notification(string path, string? detail, Variant? data);
	
	public Variant? query_meta()
	{
		try
		{
			var dict = new VariantDict(call_sync(IpcApi.CORE_GET_METADATA, null));
			dict.insert_value("running", new Variant.boolean(true));
			var capatibilities_array = new VariantBuilder(new VariantType("as"));
			var capatibilities = get_capatibilities();
			foreach (var capability in capatibilities)
				capatibilities_array.add("s", capability);
			dict.insert_value("capabilities", capatibilities_array.end());
			return dict.end();
		}
		catch (GLib.Error e)
		{
			warning("Failed to query metadata: %s", e.message);
			return null;
		}
	}
	
	public List<unowned string> get_capatibilities()
	{
		return capatibilities.get_values();
	}
	
	public bool has_capatibility(string capatibility)
	{
		return capatibilities.contains(capatibility.down());
	}
	
	public void add_capatibility(string capatibility)
	{
		capatibilities.add(capatibility.down());
	}
	
	public bool remove_capatibility(string capatibility)
	{
		return capatibilities.remove(capatibility.down());
	}
	
	/**
	 * Emitted when the subprocess exited.
	 */
	public signal void exited();
	
	public void connect_channel(Drt.ApiChannel channel)
	{
		this.channel = channel;
		channel.api_router.notification.connect(on_notification);
	}
	
	public Variant? call_sync(string name, Variant? params) throws GLib.Error
	{
		if (channel == null)
			throw new Drt.MessageError.IOERROR("No connected to app runner '%s'.", app_id);
		
		return channel.call_sync(name, params);
	}
	
	public async Variant? call_full(string method, bool allow_private, string flags, Variant? params) throws GLib.Error
	{
		if (channel == null)
			throw new Drt.MessageError.IOERROR("No connected to app runner '%s'.", app_id);
		
		return yield channel.call_full(method, allow_private, flags, params);
	}
	
	public Variant? call_full_sync(string method, bool allow_private, string flags, Variant? params) throws GLib.Error
	{
		if (channel == null)
			throw new Drt.MessageError.IOERROR("No connected to app runner '%s'.", app_id);
		
		return channel.call_full_sync(method, allow_private, flags, params);
	}
	
	private void on_notification(Drt.ApiRouter router, GLib.Object source, string path, string? detail, Variant? data)
	{
		if (source == channel)
			notification(path, detail, data);
	}
}


public class SubprocessAppRunner : AppRunner
{		
	private GLib.Subprocess process;
	private string? stderr_last_line = null;
	
	public SubprocessAppRunner(string app_id, string[] argv, string api_token) throws GLib.Error
	{
		base(app_id, api_token);
		process = new GLib.Subprocess.newv(argv, GLib.SubprocessFlags.STDIN_PIPE|GLib.SubprocessFlags.STDERR_PIPE);
		running = true;
		log_stderr.begin(on_log_stderr_done);
		pass_api_token.begin(api_token, pass_api_token_done);
		process.wait_async.begin(null, on_wait_async_done);
	}

	private async void log_stderr()
	{
		while (running)
		{
			uint8[] buffer = new uint8[1024];
			try
			{
				yield process.get_stderr_pipe().read_async(buffer);
				unowned string str = (string) buffer;
				var lines = str.split("\n");
				var size = lines.length;
				if (size == 1)
				{
					if (stderr_last_line != null && stderr_last_line[0] != '\0')
						stderr_last_line = stderr_last_line + lines[0];
					else
						stderr_last_line = lines[0];
				}
				else if (size > 1)
				{
					if (stderr_last_line != null && stderr_last_line[0] != '\0')
						stderr_print_line(stderr_last_line + lines[0]);
					else
						stderr_print_line(lines[0]);
					for (var i = 1; i < size - 1; i++)
						stderr_print_line(lines[i]);
					stderr_last_line = lines[size - 1];
				}
			}
			catch (GLib.Error e)
			{
				warning("Subprocess stderr pipe error: %s", e.message);
				break;
			}
		}
	}
	
	private void stderr_print_line(string line)
	{
		if (line.has_prefix("Worker:") || line.has_prefix("Runner:"))
			Drt.Logger.puts(line);
		else
			Drt.Logger.printf("Runner: %s", line);
		Drt.Logger.puts("\n");
	}
	
	private void on_log_stderr_done(GLib.Object? o, AsyncResult res)
	{
		log_stderr.end(res);
	}
	
	private async void pass_api_token(string api_token)
	{
		try
		{
			var stdin = process.get_stdin_pipe();
			yield stdin.write_async(api_token.data);
			yield stdin.write_async({'\n'});
		}
		catch (GLib.Error e)
		{
			warning("Subprocess stdin pipe error: %s", e.message);
		}
	}
	
	private void pass_api_token_done(GLib.Object? o, AsyncResult res)
	{
		pass_api_token.end(res);
	}
	
	private void on_wait_async_done(GLib.Object? o, AsyncResult res)
	{
		try
		{
			process.wait_async.end(res);
		}
		catch (GLib.Error e)
		{
			warning("Subprocess wait error: %s", e.message);
		}
		running = false;
		exited();
	}
}


public class DbusAppRunner : AppRunner
{		
	private uint watch_id = 0;
	
	public DbusAppRunner(string app_id, string dbus_id, string api_token) throws GLib.Error
	{
		base(app_id, api_token);
		watch_id = Bus.watch_name(BusType.SESSION, dbus_id, 0, on_name_appeared, on_name_vanished);
	}
	
	private void on_name_appeared(DBusConnection conn, string name, string name_owner)
	{
		running = true;
	}
	
	private void on_name_vanished(DBusConnection conn, string name)
	{
		Bus.unwatch_name(watch_id);
		running = false;
		exited();
	}
}

} // namespace Nuvola
