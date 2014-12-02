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
	JSON_PARSE_ERROR,
	INVALID_RESPONSE
}

private class Tiliado.Api: GLib.Object
{
	public Soup.Session connection {get; construct;}
	public string? username {get; private set; default = null;}
	public string? token {get; private set; default = null;}
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
	}
}

} // namespace Nuvola
