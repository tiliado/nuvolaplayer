/*
 * Copyright 2015-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if HAVE_WEBKIT_2_16
namespace Nuvola
{

public class NetworkSettings: Gtk.Grid
{
	
	private Connection connection;
	private Gtk.RadioButton proxy_types[4];
	private Gtk.Entry proxy_server;
	private Gtk.SpinButton proxy_port;
	private NetworkProxyType original_type;
	private string? original_host;
	private int original_port;
	
	public NetworkSettings(Connection connection)
	{
		this.connection = connection;
		original_type = connection.get_network_proxy(out original_host, out original_port);
		
		hexpand = true;
		halign = Gtk.Align.FILL;
		margin = 18;
		row_spacing = 8;
		column_spacing = 18;
		
		var row = 0;
		proxy_types = new Gtk.RadioButton[4];
		proxy_types[0] = new Gtk.RadioButton.with_label(
			null, _("Use system network proxy settings"));
		proxy_types[0].hexpand = true;
		if (original_type == NetworkProxyType.SYSTEM)
			proxy_types[0].active = true;
		attach(proxy_types[0], 0, row++, 3, 1);
		proxy_types[1] = new Gtk.RadioButton.with_label(
			proxy_types[0].get_group(), _("Use direct connection without a proxy server"));
		proxy_types[1].hexpand = true;
		if (original_type == NetworkProxyType.DIRECT)
			proxy_types[1].active = true;
		attach(proxy_types[1], 0, row++, 3, 1);
		proxy_types[2] = new Gtk.RadioButton.with_label(
			proxy_types[0].get_group(), _("Use manual HTTP proxy settings"));
		proxy_types[2].hexpand = true;
		if (original_type == NetworkProxyType.HTTP)
			proxy_types[2].active = true;
		attach(proxy_types[2], 0, row++, 3, 1);
		proxy_types[3] = new Gtk.RadioButton.with_label(
			proxy_types[0].get_group(), _("Use manual SOCKS proxy settings"));
		proxy_types[3].hexpand = true;
		if (original_type == NetworkProxyType.SOCKS)
			proxy_types[3].active = true;
		attach(proxy_types[3], 0, row++, 3, 1);
		
		var manual_settings = original_type == NetworkProxyType.HTTP || original_type == NetworkProxyType.SOCKS;
		var label = new Gtk.Label(_("Proxy Server"));
		attach(label, 0, row, 1, 1);
		proxy_server = new Gtk.Entry();
		proxy_server.text = original_host ?? "";
		proxy_server.sensitive = manual_settings;
		proxy_server.hexpand = true;
		attach(proxy_server, 1, row++, 2, 1);
		
		label = new Gtk.Label(_("Proxy Server Port"));
		attach(label, 0, row, 1, 1);
		proxy_port = new Gtk.SpinButton.with_range(0.0, (double) int32.MAX, 1.0);
		proxy_port.digits = 0;
		proxy_port.snap_to_ticks = true;
		proxy_port.value = (double) original_port;
		proxy_port.sensitive = manual_settings;
		proxy_port.hexpand = true;
		attach(proxy_port, 1, row++, 2, 1);
		
		foreach (var t in proxy_types)
			t.toggled.connect(on_proxy_type_toggled);
		proxy_server.changed.connect(on_proxy_server_changed);
		proxy_port.value_changed.connect(on_proxy_port_changed);
		
		show_all();
	}
	
	private void on_change()
	{
		proxy_server.sensitive = proxy_port.sensitive = is_manual_settings(get_proxy_type());
	}
	
	private inline bool is_manual_settings(NetworkProxyType type)
	{
		return (type == NetworkProxyType.HTTP || type == NetworkProxyType.SOCKS);
	}
	
	private NetworkProxyType get_proxy_type()
	{
		var type = NetworkProxyType.SYSTEM;
		if (proxy_types[0].active)
			type = NetworkProxyType.SYSTEM;
		else if (proxy_types[1].active)
			type = NetworkProxyType.DIRECT;
		else if (proxy_types[2].active)
			type = NetworkProxyType.HTTP;
		else if (proxy_types[3].active)
			type = NetworkProxyType.SOCKS;
		return type;
	}
	
	public bool get_proxy_settings(out NetworkProxyType type, out string? host, out int port)
	{
		host = proxy_server.text;
		if (host == "")
			host = null;
		port = (int) proxy_port.value;
		type = get_proxy_type();
		var changed = type != original_type;
		if (is_manual_settings(type) && !changed)
			changed = host != original_host || port != original_port;
		return changed;
	}
	
	private void on_proxy_type_toggled(Gtk.ToggleButton button)
	{
		if (button.active)
			on_change();
	}
	
	private void on_proxy_server_changed()
	{
		on_change();
	}
	
	private void on_proxy_port_changed()
	{
		on_change();
	}
}

} // namespace Nuvola
#endif
