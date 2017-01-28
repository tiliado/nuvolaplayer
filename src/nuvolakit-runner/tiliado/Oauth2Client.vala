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
public errordomain Oauth2Error
{
	UNKNOWN,
	PARSE_ERROR,
	RESPONSE_ERROR,
	INVALID_CLIENT,
	INVALID_REQUEST,
	HTTP_ERROR,
	HTTP_UNAUTHORIZED,
	INVALID_GRANT,
	UNAUTHORIZED_CLIENT,
	UNSUPPORTED_GRANT_TYPE;
}

public class Oauth2Client : GLib.Object
{
	private static bool debug_soup;
	public string client_id;
	public string? client_secret;
	public string api_endpoint;
	public Oauth2Token? token {get; set;}
	public string? token_endpoint;
	private Soup.Session soup;
	private string? device_code_endpoint = null;
	private string? device_code = null;
	private uint device_code_cb_id = 0;
	
	static construct
	{
		debug_soup = Environment.get_variable("OAUTH2_DEBUG_SOUP") == "yes";
	}
	
	public Oauth2Client(string client_id, string? client_secret, string api_endpoint, string? token_endpoint, Oauth2Token? token)
	{
		soup = new Soup.Session();
		if (debug_soup)
			soup.add_feature(new Soup.Logger(Soup.LoggerLogLevel.BODY, -1));
		this.client_id = client_id;
		this.client_secret = client_secret;
		this.api_endpoint = api_endpoint;
		this.token_endpoint = token_endpoint;
		this.token = token;
	}
	
	public signal void device_code_grant_cancelled();
	
	public signal void device_code_grant_finished(Oauth2Token token);
	
	public virtual signal void device_code_grant_started(string verification_uri)
	{
		debug("Device code grant verification URI: %s", verification_uri);
	}
	
	public virtual signal void device_code_grant_error(string code, string? description)
	{
		warning("Device code grant error: %s. %s", code, description ?? "(null)");
	}
	
	public virtual async Drt.JsonObject call(string? method, HashTable<string, string>? params=null,
	HashTable<string, string>? headers=null)
	throws Oauth2Error
	{
		var uri = new Soup.URI(api_endpoint + (method ?? ""));
		if (params != null)
			uri.set_query_from_form(params);
		var msg = new Soup.Message.from_uri("GET", uri);
		debug("Oauth2 GET %s", uri.to_string(false));
		if (headers != null)
			headers.for_each(msg.request_headers.replace);
		return yield send_message(msg, true);
	}
	
	public async bool refresh_token()
	throws Oauth2Error
	{
		if (token == null || token.refresh_token == null)
			return false;
		var msg = Soup.Form.request_new("POST", token_endpoint, "grant_type", "refresh_token",
				"refresh_token", token.refresh_token, "client_id", client_id);
		if (client_secret != null)
			msg.request_headers.replace("Authorization",
				"Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
		SourceFunc resume_cb = refresh_token.callback;
		soup.queue_message(msg, (s, m) => Idle.add((owned) resume_cb));
		yield;
		
		unowned string response_data = (string) msg.response_body.flatten().data;
		Drt.JsonObject response;
		try
		{
			response = Drt.JsonParser.load_object(response_data);
		}
		catch (GLib.Error e)
		{
			throw new Oauth2Error.PARSE_ERROR(e.message);
		}
		
		if (msg.status_code < 200 || msg.status_code >= 300)
		{
			string error_code; string? error_description;
			parse_error(response, out error_code, out error_description);
			if (error_description == null)
				error_description = error_code;
			else
				error_description = "%s: %s".printf(error_code, error_description);
			
			switch (error_code)
			{
			case "invalid_request":
				token = null;
				throw new Oauth2Error.INVALID_REQUEST(error_description);
			case "invalid_grant":
				token = null;
				throw new Oauth2Error.INVALID_GRANT(error_description);
			case "invalid_client":
				token = null;
				throw new Oauth2Error.INVALID_CLIENT(error_description);
			case "unauthorized_client":
				token = null;
				throw new Oauth2Error.UNAUTHORIZED_CLIENT(error_description);
			case "unsupported_grant_type":
				token = null;
				throw new Oauth2Error.UNSUPPORTED_GRANT_TYPE(error_description);
			default:
				throw new Oauth2Error.UNKNOWN("%s. %u: %s".printf(
					error_description, msg.status_code, Soup.Status.get_phrase(msg.status_code)));
			}
		}
		
		string? access_token;
		response.get_string("access_token", out access_token);
		string? refresh_token;
		response.get_string("refresh_token", out refresh_token);
		string? token_type;
		response.get_string("token_type", out token_type);
		string? scope;
		response.get_string("scope", out scope);
		token = new Oauth2Token(access_token, refresh_token, token_type, scope);
		debug("Refreshed token: %s.", token.to_string());
		return true;
	}
	
	public void start_device_code_grant(string device_code_endpoint)
	{
		var msg = Soup.Form.request_new("POST", device_code_endpoint, "response_type", "tiliado_device_code",
				"client_id", client_id);
		if (client_secret != null)
			msg.request_headers.replace("Authorization",
				"Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
		
		soup.send_message(msg);
		unowned string response_data = (string) msg.response_body.flatten().data;
		Drt.JsonObject response;
		try
		{
			response = Drt.JsonParser.load_object(response_data);
		}
		catch (GLib.Error e)
		{
			device_code_grant_error("parse_error", e.message);
			return;
		}
		
		if (msg.status_code != 200)
		{
			string error_code;
			string? error_description;
			parse_error(response, out error_code, out error_description);
			device_code_grant_error(error_code, error_description);
			return;
		}
		
		string device_code;
		if (!response.get_string("device_code", out device_code))
		{
			device_code_grant_error("response_error", "The 'device_code' member is missing.");
			return;
		}
		string verification_uri;
		if (!response.get_string("verification_uri", out verification_uri))
		{
			device_code_grant_error("response_error", "The 'verification_uri' member is missing.");
			return;
		}
		int interval;
		if (!response.get_int("interval", out interval))
			interval = 5;

		this.device_code_endpoint = device_code_endpoint;
		this.device_code = device_code;
		this.device_code_cb_id = Timeout.add_seconds((uint) interval, device_code_grant_cb);
		device_code_grant_started(verification_uri);
	}
	
	public void cancel_device_code_grant()
	{
		this.device_code = null;
		this.device_code_endpoint = null;
		if (device_code_cb_id != 0)
		{
			Source.remove(device_code_cb_id);
			device_code_cb_id = 0;
		}
		device_code_grant_cancelled();
	}
	
	public string? hmac_sha1_for_string(string data)
	{
		return hmac_for_string(ChecksumType.SHA1, data);
	}
	
	public string? hmac_for_string(ChecksumType checksum, string data)
	{
		return client_secret != null ? Hmac.compute_for_string(checksum, client_secret.data, data) : null;
	}
	
	public bool hmac_sha1_verify_string(string data, string hmac)
	{
		return hmac_verify_string(ChecksumType.SHA1, data, hmac);
	}
	
	public bool hmac_verify_string(ChecksumType checksum, string data, string hmac)
	{
		var expected_hmac = hmac_for_string(checksum, data);
		return expected_hmac != null ? Drt.Utils.const_time_byte_equal(expected_hmac.data, hmac.data) : false;
	}
	
	private async Drt.JsonObject send_message(Soup.Message msg, bool retry)
	throws Oauth2Error
	{
		if (token != null)
			msg.request_headers.replace("Authorization", "%s %s".printf(token.token_type, token.access_token));
		SourceFunc resume_cb = send_message.callback;
		soup.queue_message(msg, (s, m ) => {Idle.add((owned) resume_cb);});
		yield;
		unowned string response_data = (string) msg.response_body.flatten().data;
		if (msg.status_code < 200 || msg.status_code >= 300)
		{
			var http_error = "%u: %s".printf(msg.status_code, Soup.Status.get_phrase(msg.status_code));
			warning("Oauth2 Response error. %s.\n%s", http_error, response_data);
			switch (msg.status_code)
			{
			case 401:
				assert(token != null); 
				if (token != null && retry)
				{
					message("Failed to send a message. Will try refreshing token. Reason: %s", http_error);
					if (yield refresh_token())
						return yield send_message(msg, false);
				}
				throw new Oauth2Error.HTTP_UNAUTHORIZED(http_error);
			default:
				throw new Oauth2Error.HTTP_ERROR(http_error);
			}
		}
		
		try
		{
			return Drt.JsonParser.load_object(response_data);
		}
		catch (GLib.Error e)
		{
			throw new Oauth2Error.PARSE_ERROR(e.message);
		}
	}
	
	private bool device_code_grant_cb()
	{
		if (device_code_endpoint == null || device_code == null)
			return false;
		
		var msg = Soup.Form.request_new("POST", device_code_endpoint, "grant_type", "tiliado_device_code",
				"client_id", client_id, "code", device_code);
		if (client_secret != null)
			msg.request_headers.replace("Authorization",
				"Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
		soup.send_message(msg);
		
		if (device_code_endpoint == null || device_code == null)
			return false;
			
		unowned string response_data = (string) msg.response_body.flatten().data;
		Drt.JsonObject response;
		try
		{
			response = Drt.JsonParser.load_object(response_data);
		}
		catch (GLib.Error e)
		{
			device_code_grant_error("parse_error", e.message);
			cancel_device_code_grant();
			return false;
		}
		if (msg.status_code != 200)
		{
			string error_code;
			string? error_description;
			parse_error(response, out error_code, out error_description);
			switch (error_code)
			{
			case "slow_down":
			case "authorization_pending":
				debug("Device code grant error: %s. %s", error_code, error_description);
				return true;
			default:
				device_code_grant_error(error_code, error_description);
				cancel_device_code_grant();
				return false;
			}
		}
		
		string access_token;
		if (!response.get_string("access_token", out access_token))
		{
			device_code_grant_error("response_error", "The 'access_token' member is missing.");
			cancel_device_code_grant();
			return false;
		}
		string? refresh_token = response.get_string_or("refresh_token", null);
		string? token_type = response.get_string_or("token_type", null);
		string? scope = response.get_string_or("scope", null);
		token = new Oauth2Token(access_token, refresh_token, token_type, scope);
		debug("Device code grant token: %s.", token.to_string());
		device_code_cb_id = 0;
		this.device_code = null;
		this.device_code_endpoint = null;
		device_code_grant_finished(token);
		return false;
	}
	
	private void parse_error(Drt.JsonObject response, out string error_code, out string? error_description)
	{
		if (!response.get_string("error", out error_code))
		{
			error_code = "response_error";
			error_description = "The 'error' member is missing.";
		}
		else
		{
			error_description =response.get_string_or("description", null);
		}
	} 
}

public class Oauth2Token
{
	public string access_token {get; private set;}
	public string? refresh_token {get; private set; default = null;}
	public string? token_type {get; private set; default = null;}
	public string? scope {get; private set; default = null;}
	
	public Oauth2Token(string access_token, string? refresh_token, string? token_type, string? scope)
	{
		this.access_token = access_token;
		this.refresh_token = refresh_token;
		this.token_type = token_type;
		this.scope = scope;
	}
	
	public string to_string()
	{
		return "access='%s'; refresh='%s';type='%s';scope='%s'".printf(access_token, refresh_token, token_type, scope); 
	}
}

} // namespace Nuvola
