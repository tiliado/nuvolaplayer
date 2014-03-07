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

Diorite.Ipc.MessageClient master;
Diorite.Ipc.MessageServer slave;

public void on_web_page_created(WebKit.WebExtension extension, WebKit.WebPage web_page)
{
	warning("Page %u created for %s", (uint) web_page.get_id(), web_page.get_uri());
	Variant response;
	try
	{
		response = master.send_message("get_data_dir", new Variant.byte(0));
		message("get_data_dir: %s", response.get_string());
		response = master.send_message("get_config_dir", new Variant.byte(0));
		message("get_config_dir: %s", response.get_string());
	}
	catch (Diorite.Ipc.MessageError e)
	{
		warning("Master client error: %s", e.message);
	}
}

private void* listen()
{
	debug("Slave is listening");
	try
	{
		Nuvola.slave.listen();
	}
	catch (Diorite.IOError e)
	{
		warning("Slave server error: %s", e.message);
	}
	return null;
}

} // namespace Nuvola

public void webkit_web_extension_initialize(WebKit.WebExtension extension)
{
	Diorite.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG);
	Nuvola.master = new Diorite.Ipc.MessageClient(Environment.get_variable("NUVOLA_IPC_MASTER"), 5000);
	Nuvola.slave = new Diorite.Ipc.MessageServer(Environment.get_variable("NUVOLA_IPC_SLAVE"));
	new Thread<void*>("slave", Nuvola.listen);
	Thread.yield();
	extension.page_created.connect(Nuvola.on_web_page_created);
}
