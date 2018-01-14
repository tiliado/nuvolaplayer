/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

Nuvola.CefRendererExtension nuvola_cef_renderer_extension;

public void init_renderer_extension(CefGtk.RendererContext ctx, int browser_id, Variant?[] parameters) {
    Nuvola.Assert.on_js_thread();
    if (nuvola_cef_renderer_extension != null) {
	return;
    }
    Drt.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG, true, "Worker");
    var data = new HashTable<string, Variant>(str_hash, str_equal);
    for (var i = 2; i < parameters.length; i++) {
        data[parameters[i - 1].get_string()] = parameters[i++];
    }
    try {
	var channel = new Drt.RpcChannel.from_name(0, data["RUNNER_BUS_NAME"].dup_string(), null,
		data["NUVOLA_API_ROUTER_TOKEN"].dup_string(), 5000);
	nuvola_cef_renderer_extension = new Nuvola.CefRendererExtension(ctx, browser_id, channel, data); 
    } catch (GLib.Error e) {
	    error("Failed to connect to app runner. %s", e.message);
    }
}
