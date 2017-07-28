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

public class TiliadoActivationClient : GLib.Object, TiliadoActivation
{
	private Drt.ApiChannel master_conn;
	public TiliadoActivationClient(Drt.ApiChannel master_conn)
	{
		this.master_conn = master_conn;
		subscribe.begin((o, res) =>
		{
			try
			{
				subscribe.end(res);
			}
			catch (GLib.Error e)
			{
				warning("Failed to subscribe to notifications. %s", e.message);
			}
		});
		this.master_conn.api_router.notification.connect(on_notification_received);
	}
	
	~TiliadoActivationClient()
	{
		unsubscribe.begin((o, res) =>
		{
			try
			{
				unsubscribe.end(res);
			}
			catch (GLib.Error e)
			{
				warning("Failed to unsubscribe to notifications. %s", e.message);
			}
		});
		this.master_conn.api_router.notification.disconnect(on_notification_received);
	}
	
	private async void subscribe() throws GLib.Error
	{
		yield master_conn.subscribe(TiliadoActivationManager.ACTIVATION_STARTED);
		yield master_conn.subscribe(TiliadoActivationManager.ACTIVATION_CANCELLED);
		yield master_conn.subscribe(TiliadoActivationManager.ACTIVATION_FAILED);
		yield master_conn.subscribe(TiliadoActivationManager.ACTIVATION_FINISHED);
		yield master_conn.subscribe(TiliadoActivationManager.USER_INFO_UPDATED);
	}
	
	private async void unsubscribe() throws GLib.Error
	{
		yield master_conn.unsubscribe(TiliadoActivationManager.ACTIVATION_STARTED);
		yield master_conn.unsubscribe(TiliadoActivationManager.ACTIVATION_CANCELLED);
		yield master_conn.unsubscribe(TiliadoActivationManager.ACTIVATION_FAILED);
		yield master_conn.unsubscribe(TiliadoActivationManager.ACTIVATION_FINISHED);
		yield master_conn.unsubscribe(TiliadoActivationManager.USER_INFO_UPDATED);
	}
	
	private void on_notification_received(GLib.Object source, string name, string? detail, Variant? parameters)
	{
		switch (name)
		{
		case TiliadoActivationManager.ACTIVATION_STARTED:
			activation_started(parameters.get_string());
			break;
		case TiliadoActivationManager.ACTIVATION_CANCELLED:
			activation_cancelled();
			break;
		case TiliadoActivationManager.ACTIVATION_FAILED:
			activation_failed(parameters.get_string());
			break;
		case TiliadoActivationManager.ACTIVATION_FINISHED:
			activation_finished(TiliadoApi2.User.from_variant(parameters));
			break;
		case TiliadoActivationManager.USER_INFO_UPDATED:
			user_info_updated(TiliadoApi2.User.from_variant(parameters));
			break;
		}
	}
	
	public TiliadoApi2.User? get_user_info()
	{
		string METHOD = "/tiliado-activation/get-user-info";
		try
		{
			return TiliadoApi2.User.from_variant(master_conn.call_sync(METHOD, null));
		}
		catch (GLib.Error e)
		{
			warning("%s call failed: %s", METHOD, e.message);
		}
		return null;
	}
	
	public void update_user_info()
	{
		string METHOD = "/tiliado-activation/update-user-info";
		master_conn.call.begin(METHOD, null, (o, res) =>
		{
			try
			{
				master_conn.call.end(res);
			}
			catch (GLib.Error e)
			{
				warning("%s call failed: %s", METHOD, e.message);
			}
		});
	}
	
	public void start_activation()
	{
		string METHOD = "/tiliado-activation/start-activation";
		master_conn.call.begin(METHOD, null, (o, res) =>
		{
			try
			{
				master_conn.call.end(res);
			}
			catch (GLib.Error e)
			{
				warning("%s call failed: %s", METHOD, e.message);
			}
		});
	}
	
	public void cancel_activation()
	{
		string METHOD = "/tiliado-activation/cancel-activation";
		master_conn.call.begin(METHOD, null, (o, res) =>
		{
			try
			{
				master_conn.call.end(res);
			}
			catch (GLib.Error e)
			{
				warning("%s call failed: %s", METHOD, e.message);
			}
		});
	}
	
	public void drop_activation()
	{
		string METHOD = "/tiliado-activation/drop-activation";
		master_conn.call.begin(METHOD, null, (o, res) =>
		{
			try
			{
				master_conn.call.end(res);
			}
			catch (GLib.Error e)
			{
				warning("%s call failed: %s", METHOD, e.message);
			}
		});
	}
}

} // namespace Nuvola
#endif
