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

private class Tiliado.Account: GLib.Object
{
	public Tiliado.Api tiliado {get; private set;}
	public Diorite.KeyValueStorage config {get; construct;}
	public string project_id {get; construct;}
	public string server {get; construct;}
	public bool is_patron {get; private set; default = false;}
	
	public Account(Soup.Session connection, Diorite.KeyValueStorage config, string server, string project_id)
	{
		GLib.Object(config: config, server: server, project_id: project_id);
		tiliado = new Tiliado.Api(connection,
			server + "/api-auth/obtain-token/",
			server + "/api/",
			config.get_string("tiliado.account.username"),
			config.get_string("tiliado.account.token"));
	}
	
	public async void refresh() throws ApiError
	{
		yield tiliado.fetch_current_user();
		is_patron = yield check_is_patron();
	}
	
	private async bool check_is_patron()
	{
		if (tiliado.current_user == null)
			return false;
		
		try
		{
			var user_groups = tiliado.current_user.groups;
			var patron_groups = (yield tiliado.get_project(project_id)).patron_groups;
			for (var i = 0; i <user_groups.length; i++)
				for (var j = 0; j < patron_groups.length; j++)
					if (user_groups[i] == patron_groups[j])
						return true;
		}
		catch (ApiError e)
		{
			warning("Failed to fetch project '%s': %s", project_id, e.message);
		}
		return false;
	}
	
	public async void login(string username, string password) throws ApiError
	{
		yield tiliado.login(username, password, "nuvola,app");
		is_patron = yield check_is_patron();
		config.set_string("tiliado.account.username", tiliado.username);
		config.set_string("tiliado.account.token", tiliado.token);
	}
	
	public async void logout() throws ApiError
	{
		tiliado.log_out();
		config.unset("tiliado.account.username");
		config.unset("tiliado.account.token");
		yield refresh();
	}
}

} // namespace Nuvola
