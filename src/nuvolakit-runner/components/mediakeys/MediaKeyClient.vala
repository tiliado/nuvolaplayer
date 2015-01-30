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

public class MediaKeysClient : GLib.Object, MediaKeysInterface
{
	public bool managed {get; protected set; default=false;}
	private string app_id;
	private Diorite.Ipc.MessageClient conn;
	
	public class MediaKeysClient(string app_id, Diorite.Ipc.MessageServer server, Diorite.Ipc.MessageClient conn)
	{
		this.conn = conn;
		this.app_id = app_id;
		server.add_handler("Nuvola.MediaKeys.mediaKeyPressed", handle_media_key_pressed);
	}
	
	public void manage()
	{
		if (managed)
			return;
		
		const string METHOD = "Nuvola.MediaKeys.manage";
		try
		{
			var data = conn.send_message(METHOD, new Variant.string(app_id)); 
			Diorite.Ipc.MessageServer.check_type_str(data, "b");
			managed = data.get_boolean();
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Remote call %s failed: %s", METHOD, e.message);
		}
	}
	
	public void unmanage()
	{
		if (!managed)
			return;
		
		const string METHOD = "Nuvola.MediaKeys.unmanage";
		try
		{
			var data = conn.send_message(METHOD, new Variant.string(app_id)); 
			Diorite.Ipc.MessageServer.check_type_str(data, "b");
			managed = !data.get_boolean();
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Remote call %s failed: %s", METHOD, e.message);
		}
	}
	
	private Variant? handle_media_key_pressed(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "s");
		var key = data.get_string();
		media_key_pressed(key);
		return new Variant.boolean(true);
	}
}

} // namespace Nuvola
