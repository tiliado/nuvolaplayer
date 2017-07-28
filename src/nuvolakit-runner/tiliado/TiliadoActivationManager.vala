/*
 * Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if TILIADO_API
namespace Nuvola
{

public class TiliadoActivationManager : GLib.Object, TiliadoActivation
{
	public const string ACTIVATION_STARTED = "/tiliado-activation/activation-started";
	public const string ACTIVATION_FAILED = "/tiliado-activation/activation-failed";
	public const string ACTIVATION_CANCELLED = "/tiliado-activation/activation-cancelled";
	public const string ACTIVATION_FINISHED = "/tiliado-activation/activation-finished";
	public const string USER_INFO_UPDATED = "/tiliado-activation/user-info-updated";
	private const string TILIADO_ACCOUNT_TOKEN_TYPE = "tiliado.account2.token_type";
	private const string TILIADO_ACCOUNT_ACCESS_TOKEN = "tiliado.account2.access_token";
	private const string TILIADO_ACCOUNT_REFRESH_TOKEN = "tiliado.account2.refresh_token";
	private const string TILIADO_ACCOUNT_SCOPE = "tiliado.account2.scope";
	private const string TILIADO_ACCOUNT_MEMBERSHIP = "tiliado.account2.membership";
	private const string TILIADO_ACCOUNT_USER = "tiliado.account2.user";
	private const string TILIADO_ACCOUNT_EXPIRES = "tiliado.account2.expires";
	private const string TILIADO_ACCOUNT_SIGNATURE = "tiliado.account2.signature";
	
	public TiliadoApi2 tiliado {get; construct;}
	public Config config {get; construct;}
	public MasterBus bus {get; construct;}
	private TiliadoApi2.User? cached_user = null;
	
	public TiliadoActivationManager(TiliadoApi2 tiliado, MasterBus bus, Config config)
	{
		GLib.Object(tiliado: tiliado, config: config, bus: bus);
	}
	
	construct
	{
		tiliado.notify["token"].connect_after(on_api_token_changed);
		tiliado.notify["user"].connect_after(on_api_user_changed);
		tiliado.device_code_grant_started.connect(on_device_code_grant_started);
		tiliado.device_code_grant_error.connect(on_device_code_grant_error);
		tiliado.device_code_grant_cancelled.connect(on_device_code_grant_cancelled);
		tiliado.device_code_grant_finished.connect(on_device_code_grant_finished);
		load_cached_data();
		bus.api.add_method("/tiliado-activation/get-user-info", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_get_user_info, null);
		bus.api.add_method("/tiliado-activation/update-user-info", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_update_user_info, null);
		bus.api.add_method("/tiliado-activation/start-activation", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_start_activation, null);
		bus.api.add_method("/tiliado-activation/cancel-activation", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_cancel_activation, null);
		bus.api.add_method("/tiliado-activation/drop-activation", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_drop_activation, null);
		bus.api.add_method("/tiliado-activation/start_activation", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.READABLE,
			null, handle_start_activation, null);
		bus.api.add_notification(
			ACTIVATION_STARTED,	Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE, null);
		bus.api.add_notification(
			ACTIVATION_FAILED, Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE, null);
		bus.api.add_notification(
			ACTIVATION_CANCELLED, Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE, null);
		bus.api.add_notification(
			ACTIVATION_FINISHED, Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE, null);
		bus.api.add_notification(
			USER_INFO_UPDATED, Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE|Drt.ApiFlags.SUBSCRIBE, null);
	}
	
	~TiliadoActivationManager()
	{
		tiliado.notify["token"].disconnect(on_api_token_changed);
		tiliado.notify["user"].disconnect(on_api_user_changed);
		tiliado.device_code_grant_started.disconnect(on_device_code_grant_started);
		tiliado.device_code_grant_error.disconnect(on_device_code_grant_error);
		tiliado.device_code_grant_cancelled.disconnect(on_device_code_grant_cancelled);
		tiliado.device_code_grant_finished.disconnect(on_device_code_grant_finished);
	}
	
	public TiliadoApi2.User? get_user_info()
	{
		var current_user = tiliado.user;
		return current_user != null && current_user.is_valid() ? current_user : cached_user;
	}
	
	public void update_user_info()
	{
		tiliado.fetch_current_user.begin(on_update_current_user_done);
	}
	
	public TiliadoApi2.User? update_user_info_sync()
	{
		if (tiliado.token == null)
			return null;
		else
			return update_user_info_sync_internal();
	}
	
	public void start_activation()
	{
		tiliado.start_device_code_grant(TILIADO_OAUTH2_DEVICE_CODE_ENDPOINT);
	}
	
	public void cancel_activation()
	{
		tiliado.cancel_device_code_grant();
	}
	
	public void drop_activation()
	{
		tiliado.drop_token();
	}
	
	private Variant? handle_get_user_info(GLib.Object source, Drt.ApiParams? params) throws Drt.MessageError
	{
		var user = get_user_info();
		return user != null ? user.to_variant() : null;
	}
	
	private Variant? handle_update_user_info(GLib.Object source, Drt.ApiParams? params) throws Drt.MessageError
	{
		update_user_info();
		return null;
	}
	
	private Variant? handle_start_activation(GLib.Object source, Drt.ApiParams? params) throws Drt.MessageError
	{
		start_activation();
		return null;
	}
	
	private Variant? handle_cancel_activation(GLib.Object source, Drt.ApiParams? params) throws Drt.MessageError
	{
		cancel_activation();
		return null;
	}
	
	private Variant? handle_drop_activation(GLib.Object source, Drt.ApiParams? params) throws Drt.MessageError
	{
		drop_activation();
		return null;
	}
	
	private void on_device_code_grant_started(string url)
	{
		activation_started(url);
		bus.api.emit(ACTIVATION_STARTED, null, new Variant.string(url));
	}
	
	private void on_device_code_grant_error(string code, string? message)
	{
		string detail;
		switch (code)
		{
		case "parse_error":
		case "response_error":
			detail = "The server returned a malformed response.";
			break;
		case "invalid_client":
		case "unauthorized_client":
			detail = "This build of %s is not authorized to use the Tiliado API.".printf(Nuvola.get_app_name());
			break;
		case "access_denied":
			detail = "The authorization request has been dismissed. Please try again.";
			break;
		case "expired_token":
			detail = "The authorization request has expired. Please try again.";
			break;
		default:
			detail = "%s has sent an invalid request.".printf(Nuvola.get_app_name());
			break;
		}
		activation_failed(detail);
		bus.api.emit(ACTIVATION_FAILED, null, detail);
	}
	
	private void on_device_code_grant_cancelled()
	{
		activation_cancelled();
		bus.api.emit(ACTIVATION_CANCELLED);
	}
	
	private void on_device_code_grant_finished(Oauth2Token token)
	{
		tiliado.fetch_current_user.begin(on_get_current_user_for_activation_done);
	}
	
	private void on_get_current_user_for_activation_done(GLib.Object? o, AsyncResult res)
	{
		try
		{
			var user = tiliado.fetch_current_user.end(res);
			user = user != null && user.is_valid() ? user : null;
			activation_finished(user);
			bus.api.emit(ACTIVATION_FINISHED, null, user == null ? null : user.to_variant());
		}
		catch (Oauth2Error e)
		{
			var err = "Failed to fetch user's details. " + e.message;
			activation_failed(err);
			bus.api.emit(ACTIVATION_FAILED, null, err);
		}
		cache_user(tiliado.user);
	}
	
	private void on_update_current_user_done(GLib.Object? o, AsyncResult res)
	{
		try
		{
			var user = tiliado.fetch_current_user.end(res);
			user = user != null && user.is_valid() ? user : null;
			user_info_updated(user);
			bus.api.emit(USER_INFO_UPDATED, null, user == null ? null : user.to_variant());
		}
		catch (Oauth2Error e)
		{
			user_info_updated(null);
			bus.api.emit(USER_INFO_UPDATED);
		}
	}
	
	private void load_cached_data()
	{
		if (config.has_key(TILIADO_ACCOUNT_ACCESS_TOKEN))
		{
			tiliado.token = new Oauth2Token(
				config.get_string(TILIADO_ACCOUNT_ACCESS_TOKEN),
				config.get_string(TILIADO_ACCOUNT_REFRESH_TOKEN),
				config.get_string(TILIADO_ACCOUNT_TOKEN_TYPE),
				config.get_string(TILIADO_ACCOUNT_SCOPE));
		
			var signature = config.get_string(TILIADO_ACCOUNT_SIGNATURE);
			if (signature != null)
			{
					
				var expires = config.get_int64(TILIADO_ACCOUNT_EXPIRES);
				var user_name = config.get_string(TILIADO_ACCOUNT_USER);
				var	membership = (uint) config.get_int64(TILIADO_ACCOUNT_MEMBERSHIP);
				if (tiliado.hmac_sha1_verify_string(concat_tiliado_user_info(user_name, membership, expires), signature))
				{
					var user = new TiliadoApi2.User(0, null, user_name, true, true, new int[]{});
					user.membership = membership;
					cached_user = user;
				}
			}
		}
	}
	
	private void cache_user(TiliadoApi2.User? user)
	{
		cached_user = null;
		if (user != null && user.is_valid())
		{
			var expires = new DateTime.now_utc().add_weeks(5).to_unix();
			config.set_string(TILIADO_ACCOUNT_USER, user.name);
			config.set_int64(TILIADO_ACCOUNT_MEMBERSHIP, (int64) user.membership);
			config.set_int64(TILIADO_ACCOUNT_EXPIRES, expires);
			var signature = tiliado.hmac_sha1_for_string(
				concat_tiliado_user_info(user.name, user.membership, expires));
			config.set_string(TILIADO_ACCOUNT_SIGNATURE, signature);	
		}
		else
		{
			config.unset(TILIADO_ACCOUNT_USER);
			config.unset(TILIADO_ACCOUNT_MEMBERSHIP);
			config.unset(TILIADO_ACCOUNT_EXPIRES);
			config.unset(TILIADO_ACCOUNT_SIGNATURE);
		}
	}
	
	private inline string concat_tiliado_user_info(string name, uint membership_rank, int64 expires)
	{
		return "%s:%u:%s".printf(name, membership_rank, expires.to_string());
	}
	
	private void on_api_token_changed(GLib.Object o, ParamSpec p)
	{
		var token = tiliado.token;
		if (token != null)
		{
			config.set_value(TILIADO_ACCOUNT_TOKEN_TYPE, token.token_type);
			config.set_value(TILIADO_ACCOUNT_ACCESS_TOKEN, token.access_token);
			config.set_value(TILIADO_ACCOUNT_REFRESH_TOKEN, token.refresh_token);
			config.set_value(TILIADO_ACCOUNT_SCOPE, token.scope);
		}
		else
		{
			config.unset(TILIADO_ACCOUNT_TOKEN_TYPE);
			config.unset(TILIADO_ACCOUNT_ACCESS_TOKEN);
			config.unset(TILIADO_ACCOUNT_REFRESH_TOKEN);
			config.unset(TILIADO_ACCOUNT_SCOPE);
		}
	}
	
	private void on_api_user_changed(GLib.Object o, ParamSpec p)
	{
		var user = tiliado.user;
		cache_user(user);
		user_info_updated(user);
		bus.api.emit(USER_INFO_UPDATED, null, user == null ? null : user.to_variant());
	}
}

} // namespace Nuvola
#endif
