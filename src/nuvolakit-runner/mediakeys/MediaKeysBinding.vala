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

public class Nuvola.MediaKeysBinding: Binding<MediaKeysInterface>
{
	public MediaKeysBinding(Diorite.Ipc.MessageServer server, WebEngine web_engine)
	{
		base(server, web_engine, "Nuvola.MediaKey");
	}
	
	public override bool add(GLib.Object object)
	{
		var result = base.add(object);
		if (result)
			(object as MediaKeysInterface).media_key_pressed.connect(on_media_key_pressed);
		return result;
	}
	
	private void on_media_key_pressed(string key)
	{
		try
		{
			call_web_worker("Nuvola.mediaKeys.emit", new Variant("(ss)", "MediaKeyPressed", key));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			warning("Communication failed: %s", e.message);
		}
	}
}
