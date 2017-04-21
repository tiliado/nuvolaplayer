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

namespace Nuvola
{

public enum TiliadoMembership
{
	NONE = 0,
	PREMIUM = 1,
	PREMIUM_PLUS = 2,
	PATRON = 3,
	PATRON_PLUS = 4,
	DEVELOPER = 5;
}

public class TiliadoApi2 : Oauth2Client
{
	public User? user {get; private set; default = null;}
	public string? project_id {get; private set; default = null;}
	
	public TiliadoApi2(string client_id, string? client_secret, string api_endpoint, string token_endpoint,
		Oauth2Token? token, string? project_id=null)
	{
		base(client_id, client_secret, api_endpoint, token_endpoint, token);
		this.project_id = project_id;
	}
	
	public async User fetch_current_user() throws Oauth2Error
	{
		var response = yield call("me/");
		if (response.get_bool_or("is_authenticated", false) == false)
		{
			// Try refreshing the token to get an authenticated user
			yield refresh_token();
			response = yield call("me/");
		}
		int[] groups;
		if (!response.get_int_array("groups", out groups))
			groups = {};
		var user = new User(
			response.get_int_or("id", 0),
			response.get_string_or("username", null),
			response.get_string_or("name", null),
			response.get_bool_or("is_authenticated", false),
			response.get_bool_or("is_active", false),
			(owned) groups);
		if (project_id != null)
			yield set_account_membership(user, project_id);
		this.user = user;
		return user;
	}
	
	public async void set_account_membership(User user, string project_id) throws Oauth2Error
	{
		var project = yield get_project(project_id);
		unowned int[] user_groups = user.groups;
		unowned int[] patron_groups = project.patron_groups;
		int membership = 0;
		for (var i = 0;  i < user.groups.length; i++)
		{
			for (var j = 0; j < project.patron_groups.length; j++)
			{
				if (user_groups[i] == patron_groups[j])
				{
					var group = yield get_group(user_groups[i]);
					membership = int.max(membership, group.membership_rank);
				}
			}
		}
		user.membership = (uint) membership;
	}
	
	public async Project get_project(string id) throws Oauth2Error
	{
		var response = yield call("projects/projects/%s".printf(id));
		int[] groups;
		if (!response.get_int_array("patron_groups", out groups))
			groups = {};
		return new Project(
			response.get_string_or("id", id),
			response.get_string_or("name", id),
			(owned) groups);
	}
	
	public async Group get_group(int id) throws Oauth2Error
	{
		var response = yield call("auth/groups/%d".printf(id));
		int[] groups;
		if (!response.get_int_array("patron_groups", out groups))
			groups = {};
		return new Group(
			response.get_int_or("id", id),
			response.get_string_or("name", id.to_string()),
			response.get_int_or("membership_rank", 0));
	}
	
	public class User
	{
		public int id {get; private set;}
		public string? username {get; private set;}
		public string? name {get; private set;}
		public bool is_authenticated {get; private set;}
		public bool is_active {get; private set;}
		public int[] groups {get; private set;}
		public uint membership {get; set; default = 0;}
		
		public class User(int id, string? username, string? name, bool is_authenticated, bool is_active, owned int[] groups)
		{
			this.id = id;
			this.username = username;
			this.name = name;
			this.is_authenticated = is_authenticated;
			this.is_active = is_active;
			this.groups = (owned) groups;
		}
		
		public bool has_membership(uint membership)
		{
			return this.membership >= membership;
		}
		
		public string to_string()
		{
			return id == 0 ? "null" : "%s (%s, %d, %u)".printf(name, username, id, membership);
		}
	}
	
	public class Project
	{
		public string id {get; private set;}
		public string name {get; private set;}
		public int[] patron_groups {get; private set;}
		
		public class Project(string id, string name, owned int[] patron_groups)
		{
			this.id = id;
			this.name = name;
			this.patron_groups = (owned) patron_groups;
		}
		
		public string to_string()
		{
			return "%s (%s)".printf(name, id);
		}
	}
	
	public class Group
	{
		public int id {get; private set;}
		public string name {get; private set;}
		public int membership_rank {get; private set;}
		
		public Group(int id, string name, int membership_rank)
		{
			this.id = id;
			this.name = name;
			this.membership_rank = membership_rank;
		}
		
		public string to_string()
		{
			return "%d:%s".printf(id, name);
		}
	}
}

} // namespace Nuvola
