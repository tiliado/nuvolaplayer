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

public class AppRunner: Diorite.Subprocess
{
	public string app_id {get; private set;}
	public bool connected { get{ return client != null;} }
	private Diorite.Ipc.MessageClient? client = null;
	private uint check_server_connected_id = 0;
	
	public AppRunner(string app_id, string[] argv) throws GLib.Error
	{
		base(argv, Diorite.SubprocessFlags.INHERIT_FDS);
		this.app_id = app_id;
		check_server_connected_id = Timeout.add_seconds(5, check_server_connected_cb);
	}
	
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
	
	public Variant send_message(string name, Variant params) throws Diorite.Ipc.MessageError
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
			force_exit();
		
		return false;
	}
}

} // namespace Nuvola
