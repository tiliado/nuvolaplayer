/*
 * Copyright 2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola.Nm
{

private static T[]? get_proxies<T>(BusType bus, string name, ObjectPath[]? entries)
{
	if (entries == null || entries.length == 0)
		return null;
	try
	{
		var result = new T[entries.length];
		for (var i = 0; i < entries.length; i++)
			result[i] = Bus.get_proxy_sync<T>(bus, name, entries[i], 0, null);
		return result;
	}
	catch (GLib.Error e)
	{
		debug("Failed to get DBus proxy. %s", e.message);
		return null;
	}
}

private const string BUS_NAME = "org.freedesktop.NetworkManager";

[DBus(name = "org.freedesktop.NetworkManager")]
public interface NetworkManager : GLib.Object
{
	private abstract ObjectPath[] ActiveConnections{owned get;}
	
	[DBus(visible=false)]
	public ActiveConnection[]? get_active_connections()
	{
		return get_proxies<ActiveConnection>(BusType.SYSTEM, BUS_NAME, ActiveConnections);
	}
}

[DBus(name = "org.freedesktop.NetworkManager.Connection.Active")]
public interface ActiveConnection : GLib.Object
{
	private abstract ObjectPath? Ip4Config {owned get;}
	public abstract string? id {owned get;}
	
	[DBus(visible=false)]
	public Ip4Config? get_ip4_config()
	{
		var path = Ip4Config;
		if (path == null)
			return null;
		try
		{
			return Bus.get_proxy_sync<Ip4Config>(BusType.SYSTEM, BUS_NAME, path, 0, null);
		}
		catch (GLib.Error e)
		{
			debug("Failed to get DBus proxy for '%s'. %s", path, e.message);
			return null;
		}
	}
}

[DBus(name = "org.freedesktop.NetworkManager.IP4Config")]
public interface Ip4Config : GLib.Object
{
	public uint[]? get_addresses()
	{
		uint[] result = {};
		var addresses = (this as DBusProxy).get_cached_property("Addresses");
		var iter = addresses.iterator();
		VariantIter iter2 = null;
		while(iter.next ("au", out iter2))
		{
			uint32 ip4 = 0;
			while (iter2.next("u", out ip4))
			{
				result += ip4;
				break;
			}
		}
		return result.length > 0 ? result : null;
	}
}

public static async NetworkManager? get_client(Cancellable? cancellable) throws GLib.Error
{
   return yield Bus.get_proxy<NetworkManager>(BusType.SYSTEM, BUS_NAME, "/org/freedesktop/NetworkManager", 0, cancellable);
}


} // namespace Nm

