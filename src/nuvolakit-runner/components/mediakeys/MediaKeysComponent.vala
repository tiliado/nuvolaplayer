/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MediaKeysComponent: Component
{
	#if !NUVOLA_LITE
	private Bindings bindings;
	private Drtgtk.Application app;
	private MediaKeysClient? media_keys = null;
	private Drt.RpcChannel conn;
	private string web_app_id;
	#endif
	
	public MediaKeysComponent(Drtgtk.Application app, Bindings bindings, Drt.KeyValueStorage config, Drt.RpcChannel? conn, string web_app_id)
	{
		base("mediakeys", "Media keys", "Handles multimedia keys of your keyboard.");
		#if !NUVOLA_LITE
		assert(conn != null);
		this.bindings = bindings;
		this.app = app;
		this.conn = conn;
		this.web_app_id = web_app_id;
		config.bind_object_property("component.mediakeys.", this, "enabled").set_default(true).update_property();
		auto_activate = false;
		#else
		available = false;
		#endif
	}
	
	#if !NUVOLA_LITE
	protected override bool activate()
	{
		media_keys = new MediaKeysClient(web_app_id, conn);
		bindings.add_object(media_keys);
		media_keys.manage();
		return true;
	}
	
	protected override bool deactivate()
	{
		bindings.remove_object(media_keys);
		media_keys.unmanage();
		media_keys = null;
		return true;
	}
	#endif
}

} // namespace Nuvola
