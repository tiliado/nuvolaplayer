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

private errordomain Tiliado.ApiError
{
	UNKNOWN_ERROR,
	INVALID_CREDENTIALS,
	AUTHENTICATION_FAILED,
	UNAUTHORIZED,
	JSON_PARSE_ERROR,
	INVALID_RESPONSE
}

private class Tiliado.User
{
	public int id {get; private set;}
	public string username {get; private set;}
	public string name {get; private set;}
	public bool is_authenticated {get; private set;}
	public bool is_active {get; private set;}
	public int[] groups {get; private set;}
	
	public class User(int id, string username, string name, bool is_authenticated, bool is_active, owned int[] groups)
	{
		this.id = id;
		this.username = username;
		this.name = name;
		this.is_authenticated = is_authenticated;
		this.is_active = is_active;
		this.groups = (owned) groups;
	}
	
	public string to_string()
	{
		return "%s (%s)".printf(name, username);
	}
}

private class Tiliado.Api: GLib.Object
{
	public Soup.Session connection {get; construct;}
	public string? username {get; private set; default = null;}
	public string? token {get; private set; default = null;}
	public User? current_user {get; private set; default = null;}
	private string api_root;
	private string api_auth;
	
	public Api(Soup.Session connection, string api_auth, string api_root, string? username=null, string? token=null)
	{
		GLib.Object(connection: connection);
		this.api_root = api_root;
		this.api_auth = api_auth;
		this.username = username;
		this.token = token;
	}
	
	public async void login(string username, string password, string scope) throws ApiError
	{
		if (username == "")
			throw new ApiError.INVALID_CREDENTIALS("Username is empty.");
		if (password == "")
			throw new ApiError.INVALID_CREDENTIALS("Password is empty.");
		if (scope == "")
			throw new ApiError.INVALID_CREDENTIALS("Scope is empty.");
		
		var message = Soup.Form.request_new(
			"POST", api_auth, "username", username, "password", password, "scope", scope, null);
		
		SourceFunc callback = login.callback;
		connection.queue_message(message, () => {Idle.add((owned) callback);});
		yield;
		
		if (message.status_code == 400)
			throw new ApiError.AUTHENTICATION_FAILED("Unable to login with provided credentials.");
		
		if (message.status_code >= 300)
			throw new ApiError.UNKNOWN_ERROR("Unexpected error: %u %s", message.status_code, message.reason_phrase);
		
		var response = (string) message.response_body.flatten().data;
		var parser = new Json.Parser();
		try
		{
			parser.load_from_data(response);
		}
		catch (GLib.Error e)
		{
			debug("Response: \n%s", response);
			throw new ApiError.JSON_PARSE_ERROR(e.message);
		}
		
		var root_node = parser.get_root();
		if (root_node == null)
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Null root node.");
		
		var reader = new Json.Reader(root_node);
		if (!reader.is_object())
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Root node is not object.");
		
		if (!reader.read_member("token"))
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Token member not found.");
		
		if (!reader.is_value() || reader.get_value().get_value_type() != typeof(string))
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Token member is not a string.");
		this.username = username;
		this.token = reader.get_string_value();
		reader.end_member();
		
		yield fetch_current_user();
	}
	
	public void log_out()
	{
		username = null;
		token = null;
		current_user = null;
	}
	
	public async Soup.Message send_request(string method, string path, HashTable<string, string>? form_data_set=null)
		throws ApiError
	{
		var uri = api_root + path;
		var message = form_data_set == null
		? new Soup.Message(method, uri) : Soup.Form.request_new_from_hash(method, uri, form_data_set);
		
		if (username != null && token != null)
			message.request_headers.append("Authorization", "Token %s %s".printf(Base64.encode(username.data), token));
		
		SourceFunc callback = send_request.callback;
		connection.queue_message(message, () => {Idle.add((owned) callback);});
		yield;
		return message;
	}
	
	public async Json.Reader send_request_json(string method, string path,
		HashTable<string, string>? form_data_set=null) throws ApiError
	{
		var message = yield send_request(method, path, form_data_set);
		if (message.status_code == 400)
			throw new ApiError.AUTHENTICATION_FAILED("Unable to login with provided credentials.");
		
		if (message.status_code == 401)
			throw new ApiError.UNAUTHORIZED("Tiliado account session seems to be expired.");
		
		if (message.status_code > 401)
			throw new ApiError.UNKNOWN_ERROR("Unexpected error: %u %s", message.status_code, message.reason_phrase);
		
		var response = (string) message.response_body.flatten().data;
		var parser = new Json.Parser();
		try
		{
			parser.load_from_data(response);
		}
		catch (GLib.Error e)
		{
			debug("Response: \n%s", response);
			throw new ApiError.JSON_PARSE_ERROR(e.message);
		}
		
		var root_node = parser.get_root();
		if (root_node == null)
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Null root node.");
		
		var reader = new Json.Reader(root_node);
		if (!reader.is_object())
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: Root node is not object.");
		
		return reader;
	}
	
	public async void fetch_current_user() throws ApiError
	{
		var reader = yield send_request_json("GET", "me/");
		
		var id = read_int64(reader, "id");
		var name = read_string(reader, "name");
		var username = read_string(reader, "username");
		bool is_active;
		try
		{
			is_active = read_bool(reader, "is_active");
		}
		catch (ApiError e)
		{
			is_active = false;
		}
		bool is_authenticated;
		try
		{
			is_authenticated = read_bool(reader, "is_authenticated");
		}
		catch (ApiError e)
		{
			is_authenticated = false;
		}
		int[] groups;
		try
		{
			groups = read_int_array(reader, "groups");
		}
		catch (ApiError e)
		{
			groups = {};
		}
		
		current_user = new User((int) id, username, name, is_authenticated, is_active, groups);
	}
	
	private Json.Node read_value(Json.Reader reader, string member_name) throws ApiError
	{
		if (!reader.read_member(member_name))
		{
			reader.end_member();
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member not found.", member_name);
		}
		
		if (!reader.is_value())
		{
			reader.end_member();
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member is not a value type.", member_name);
		}
		
		var node = reader.get_value();
		reader.end_member();
		return node;
	}
	
	private bool read_bool(Json.Reader reader, string member_name) throws ApiError
	{
		var node = read_value(reader, member_name);
		if (node.get_value_type() != typeof(bool))
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member is not a bool type.", member_name);
		
		return node.get_boolean();
	}
	
	private int64 read_int64(Json.Reader reader, string member_name) throws ApiError
	{
		var node = read_value(reader, member_name);
		if (node.get_value_type() != typeof(int64))
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member is not an int64 type.", member_name);
		
		return node.get_int();
	}
	
	private string read_string(Json.Reader reader, string member_name) throws ApiError
	{
		var node = read_value(reader, member_name);
		if (node.get_value_type() != typeof(string))
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member is not a string type.", member_name);
		
		return node.get_string();
	}
	
	private int[] read_int_array(Json.Reader reader, string member_name) throws ApiError
	{
		if (!reader.read_member(member_name))
		{
			reader.end_member();
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member not found.", member_name);
		}
		
		if (!reader.is_array())
		{
			reader.end_member();
			throw new ApiError.INVALID_RESPONSE("Invalid response from server: '%s' member is not an array type.", member_name);
		}
		
		var size = reader.count_elements();
		var array = new int[size];
		for (var i = 0; i < size; i++)
		{
			reader.read_element(i);
			if (!reader.is_value())
			{
				reader.end_element();
				throw new ApiError.INVALID_RESPONSE("Invalid response from server: %s[%d] element is not a value type.", member_name, i);
			}
			
			var node = reader.get_value();
			reader.end_element();
			if (node.get_value_type() != typeof(int64))
				throw new ApiError.INVALID_RESPONSE("Invalid response from server: %s[%d] element is not an int64 type.", member_name, i);
			array[i] = (int) node.get_int();
		}
		return array;
	}
}

} // namespace Nuvola
