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
	UNKNOWN, PARSE_ERROR, RESPONSE_ERROR, INVALID_CLIENT, INVALID_REQUEST;
}

public class Oauth2Client : GLib.Object
{
	public string client_id;
	public string? client_secret;
	public string api_endpoint;
	public Oauth2Token? token
	{
		get
		{ 
			return this._token;
		}
		set
		{
			this._token = value;
			rest.set_access_token(this._token != null ? token.access_token : null);
		}
	}
	public string? token_endpoint;
	private Soup.Session soup;
	private Rest.OAuth2Proxy rest;
	private string? device_code_endpoint = null;
	private string? device_code = null;
	private uint device_code_cb_id = 0;
	public Oauth2Token? _token = null;
	
	public Oauth2Client(string client_id, string? client_secret, string api_endpoint, string? token_endpoint, Oauth2Token? token)
	{
		soup = new Soup.Session();
		rest = new Rest.OAuth2Proxy(client_id, "http://127.0.0.1", api_endpoint, false);
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
	
	public virtual async JsonReader call(string? method, HashTable<string, string>? params=null, HashTable<string, string>? headers=null) throws Oauth2Error
	{
		var request = rest.new_call();
		request.set_method("GET");
		if (method != null)
			request.set_function(method);
		if (params != null)
			params.for_each(request.add_param);
		if (headers != null)
			headers.for_each(request.add_header);
		
		SourceFunc cb = call.callback;
		GLib.Error? err = null;
		try
		{
			request.run_async((req, error, obj) => {
				err = error;
				Idle.add((owned) cb);
			});
			yield;
		}
		catch (GLib.Error e)
		{
			err = e;
		}
		
		if (err != null)
		{
		
			warning("Rest error: %s", err.message);
			throw new Oauth2Error.UNKNOWN(err.message);
		}
		var status_code = request.get_status_code();
		var payload = request.get_payload();
		
		warning("%u: %s", status_code, payload);
		var reader = new JsonReader();
		try
		{
			reader.load_from_data(payload);
		}
		catch (GLib.Error e)
		{
			throw new Oauth2Error.PARSE_ERROR(e.message);
		}
		return reader;
	}
	
	public void start_device_code_grant(string device_code_endpoint)
	{
		var msg = Soup.Form.request_new("POST", device_code_endpoint, "response_type", "tiliado_device_code",
				"client_id", client_id);
		if (client_secret != null)
			msg.request_headers.replace("Authorization",
				"Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
		
		soup.send_message(msg);
		unowned string response = (string) msg.response_body.flatten().data;
		var reader = new JsonReader();
		try
		{
			reader.load_from_data(response);
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
			parse_error(reader, out error_code, out error_description);
			device_code_grant_error(error_code, error_description);
			return;
		}
		
		string device_code;
		if (!reader.string_member("device_code", out device_code))
		{
			device_code_grant_error("response_error", "The 'device_code' member is missing.");
			return;
		}
		string verification_uri;
		if (!reader.string_member("verification_uri", out verification_uri))
		{
			device_code_grant_error("response_error", "The 'verification_uri' member is missing.");
			return;
		}
		int interval;
		if (!reader.int_member("interval", out interval))
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
			
		unowned string response = (string) msg.response_body.flatten().data;
		var reader = new JsonReader();
		try
		{
			reader.load_from_data(response);
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
			parse_error(reader, out error_code, out error_description);
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
		if (!reader.string_member("access_token", out access_token))
		{
			device_code_grant_error("response_error", "The 'access_token' member is missing.");
			cancel_device_code_grant();
			return false;
		}
		string? refresh_token;
		reader.string_member("refresh_token", out refresh_token);
		string? token_type;
		reader.string_member("token_type", out token_type);
		string? scope;
		reader.string_member("scope", out scope);
		token = new Oauth2Token(access_token, refresh_token, token_type, scope);
		debug("Device code grant token: %s.", token.to_string());
		device_code_cb_id = 0;
		this.device_code = null;
		this.device_code_endpoint = null;
		device_code_grant_finished(token);
		return false;
	}
	
	private void parse_error(JsonReader reader, out string error_code, out string? error_description)
	{
		if (!reader.string_member("error", out error_code))
		{
			error_code = "response_error";
			error_description = "The 'error' member is missing.";
		}
		else
		{
			reader.string_member("description", out error_description);
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
