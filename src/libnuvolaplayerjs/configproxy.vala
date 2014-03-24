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

public class ConfigProxy: GLib.Object, KeyValueStorage
{
	private Diorite.Ipc.MessageClient client;
	
	public ConfigProxy(Diorite.Ipc.MessageClient client)
	{
		this.client = client;
	}
	
	public bool save() throws GLib.Error
	{
		var response = client.send_message("config_save", new Variant.byte(0));
		if (response.is_of_type(VariantType.BOOLEAN))
			return response.get_boolean();
		critical("Invalid response to config_save: %s", response.print(false));
		return false;
	}
	
	public bool has_key(string key)
	{
		try
		{
			var response = client.send_message("config_has_key", new Variant.string(key));
			if (response.is_of_type(VariantType.BOOLEAN))
				return response.get_boolean();
			critical("Invalid response to config_has_key: %s", response.print(false));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Master client error: %s", e.message);
		}
		return false;
	}
	
	public Variant? get_value(string key)
	{
		try
		{
			var response = client.send_message("config_get_value", new Variant.string(key));
			return response;
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Master client error: %s", e.message);
			return null;
		}
	}
	
	public void set_value(string key, Variant? value)
	{
		try
		{
			client.send_message("config_set_value", new Variant("(smv)", key, value));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Master client error: %s", e.message);
		}
	}
	
	public void set_default_value(string key, Variant? value)
	{
		try
		{
			client.send_message("config_set_default_value", new Variant("(smv)", key, value));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			critical("Master client error: %s", e.message);
		}
	}
}

} // namespace Nuvola
