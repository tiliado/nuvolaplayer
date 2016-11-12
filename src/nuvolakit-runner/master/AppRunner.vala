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

public class AppRunner : GLib.Object
{
	private static bool gdb = false;
	public string app_id {get; private set;}
	public bool connected {get{ return client != null;}}
	public bool running {get; private set; default = false;}
	private Diorite.Ipc.MessageClient? client = null;
	private uint check_server_connected_id = 0;
	private GLib.Subprocess process;
	private string? stderr_last_line = null;
	
	static construct
	{
		gdb = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER") != null;
	}
	
	public AppRunner(string app_id, string[] argv) throws GLib.Error
	{
		this.app_id = app_id;
		process = new GLib.Subprocess.newv(argv, GLib.SubprocessFlags.STDIN_INHERIT|GLib.SubprocessFlags.STDERR_PIPE);
		running = true;
		log_stderr.begin(on_log_stderr_done);
		process.wait_async.begin(null, on_wait_async_done);
		check_server_connected_id = Timeout.add_seconds(gdb ? 600 : 30, check_server_connected_cb);
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
			Diorite.Logger.puts(line);
		else
			Diorite.Logger.printf("Runner: %s", line);
		Diorite.Logger.puts("\n");
	}
	
	private void on_log_stderr_done(GLib.Object? o, AsyncResult res)
	{
		log_stderr.end(res);
	}
	
	/**
	 * Emitted when the subprocess exited.
	 */
	public signal void exited();
	
	public bool connect_server(string server_name)
	{
		if (client != null)
			return false;
		
		if (check_server_connected_id != 0)
		{
			Source.remove(check_server_connected_id);
			check_server_connected_id = 0;
		}
		
		client = new Diorite.Ipc.MessageClient(server_name, 5000);
		return true;
	}
	
	public Variant? send_message(string name, Variant? params) throws Diorite.Ipc.MessageError
	{
		if (client == null)
			throw new Diorite.Ipc.MessageError.IOERROR("No connected to app runner '%s'.", app_id);
		
		return client.send_message(name, params);
	}
	
	private bool check_server_connected_cb()
	{
		check_server_connected_id = 0;
		warning("Connection has not been se up in time for app runner '%s'.", app_id);
		
		if (running)
			process.force_exit();
		
		return false;
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

} // namespace Nuvola
