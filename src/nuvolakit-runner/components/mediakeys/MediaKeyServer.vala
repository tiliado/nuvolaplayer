/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MediaKeysServer: GLib.Object
{
	private MediaKeysInterface media_keys;
	private Diorite.Ipc.MessageServer server;
	private unowned Queue<AppRunner> app_runners;
	private GenericSet<string> clients;
	
	public MediaKeysServer(MediaKeysInterface media_keys, Diorite.Ipc.MessageServer server, Queue<AppRunner> app_runners)
	{
		this.media_keys = media_keys;
		this.server = server;
		this.app_runners = app_runners;
		clients = new GenericSet<string>(str_hash, str_equal);
		media_keys.media_key_pressed.connect(on_media_key_pressed);
		server.add_handler("Nuvola.MediaKeys.manage", "s", handle_manage);
		server.add_handler("Nuvola.MediaKeys.unmanage", "s", handle_unmanage);
	}
	
	private Variant? handle_manage(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var app_id = data.get_string();
		
		if (app_id in clients)
			return new Variant.boolean(false);
		
		clients.add(app_id);
		if (clients.length == 1 && !media_keys.managed)
			media_keys.manage();
		
		return new Variant.boolean(true);
	}
	
	private Variant? handle_unmanage(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		var app_id = data.get_string();
		
		if (!(app_id in clients))
			return new Variant.boolean(false);
		
		clients.remove(app_id);
		if (clients.length == 0 && media_keys.managed)
			media_keys.unmanage();
		
		return new Variant.boolean(true);
	}
	
	private void on_media_key_pressed(string key)
	{
		unowned List<AppRunner> head = app_runners.head;
		var handled = false;
		foreach (var app_runner in head)
		{
			var app_id = app_runner.app_id;
			if (app_id in clients)
			{
				try
				{
					var response = app_runner.send_message("Nuvola.MediaKeys.mediaKeyPressed", new Variant.string(key));
					if (!Diorite.variant_bool(response, ref handled))
					{
						warning("Nuvola.MediaKeys.mediaKeyPressed got invalid response from %s instance %s: %s\n", Nuvola.get_app_name(), app_id,
							response == null ? "null" : response.print(true));
					}
				}
				catch (GLib.Error e)
				{
					warning("Communication with app runner %s for action %s failed. %s", app_id, key, e.message);
				}
				
				if (handled)
					break;
			}
		}
		
		if (!handled)
			warning("MediaKey %s was not handled by any app runner.", key);
	}
}

} // namespace Nuvola
