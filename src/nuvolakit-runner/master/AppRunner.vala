/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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
	public bool connected {get{ return channel != null;}}
	public bool running {get; private set; default = false;}
	private Drt.MessageChannel channel = null;
	private GLib.Subprocess process;
	
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
				if (str.has_prefix("Worker:") || str.has_prefix("Runner:"))
					Diorite.Logger.puts(str);
				else
					Diorite.Logger.printf("Runner: %s", str);
			}
			catch (GLib.Error e)
			{
				warning("Subprocess stderr pipe error: %s", e.message);
				break;
			}
		}
	}
	
	private void on_log_stderr_done(GLib.Object? o, AsyncResult res)
	{
		log_stderr.end(res);
	}
	
	/**
	 * Emitted when the subprocess exited.
	 */
	public signal void exited();
	
	public void connect_channel(Drt.MessageChannel channel)
	{
		this.channel = channel;
	}
	
	public Variant? send_message(string name, Variant? params) throws GLib.Error
	{
		if (channel == null)
			throw new Diorite.MessageError.IOERROR("No connected to app runner '%s'.", app_id);
		
		return channel.send_message(name, params);
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
