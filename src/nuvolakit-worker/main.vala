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

namespace Nuvola
{

public WebExtension extension;

} // namespace Nuvola

public void webkit_web_extension_initialize_with_user_data(WebKit.WebExtension extension, Variant data)
{
	Drt.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG, true, "Worker");
	
	var debug_sleep = Environment.get_variable("NUVOLA_WEB_WORKER_SLEEP");
	if (debug_sleep != null)
	{
		var seconds = int.parse(debug_sleep);
		if (seconds > 0)
		{
			warning("WebWorker is going to sleep for %d seconds.", seconds);
			warning("Run `gdb -p %d` to debug it with gdb.", (int) Posix.getpid());
			GLib.Thread.usleep(seconds * 1000000);
			warning("WebWorker is awake.");
		}
		else
		{
			warning("Invalid NUVOLA_WEB_WORKER_SLEEP variable: %s", debug_sleep);
		}
	}
	
	if (Environment.get_variable("NUVOLA_TEST_ABORT") == "worker")
		error("Web Worker abort requested.");
		
	var worker_data = Drt.variant_to_hashtable(data);
	try
	{
		var channel = new Drt.RpcChannel.from_name(0, worker_data["RUNNER_BUS_NAME"].dup_string(), null,
			worker_data["NUVOLA_API_ROUTER_TOKEN"].dup_string(), 5000);
		Nuvola.extension = new Nuvola.WebExtension(extension, channel, worker_data); 
	}
	catch (GLib.Error e)
	{
		error("Failed to connect to app runner. %s", e.message);
	}
}
