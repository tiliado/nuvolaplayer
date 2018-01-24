/*
 * Copyright 2011-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MediaKeysServer: GLib.Object
{
    private MediaKeysInterface media_keys;
    private Drt.RpcBus ipc_bus;
    private unowned Queue<AppRunner> app_runners;
    private GenericSet<string> clients;

    public MediaKeysServer(MediaKeysInterface media_keys, Drt.RpcBus ipc_bus, Queue<AppRunner> app_runners)
    {
        this.media_keys = media_keys;
        this.ipc_bus = ipc_bus;
        this.app_runners = app_runners;
        clients = new GenericSet<string>(str_hash, str_equal);
        media_keys.media_key_pressed.connect(on_media_key_pressed);
        ipc_bus.router.add_method("/nuvola/mediakeys/manage", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_manage, {
            new Drt.StringParam("id", true, false)
        });
        ipc_bus.router.add_method("/nuvola/mediakeysl/unmanage", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_unmanage, {
            new Drt.StringParam("id", true, false)
        });
    }

    private void handle_manage(Drt.RpcRequest request) throws Drt.RpcError {
        var app_id = request.pop_string();
        if (app_id in clients){
            request.respond(new Variant.boolean(false));
        } else {
            clients.add(app_id);
            if (clients.length == 1 && !media_keys.managed) {
                media_keys.manage();
            }
            request.respond(new Variant.boolean(true));
        }
    }

    private void handle_unmanage(Drt.RpcRequest request) throws Drt.RpcError {
        var app_id = request.pop_string();
        if (!(app_id in clients)) {
            request.respond(new Variant.boolean(false));
        } else {
            clients.remove(app_id);
            if (clients.length == 0 && media_keys.managed) {
                media_keys.unmanage();
            }
            request.respond(new Variant.boolean(true));
        }
    }

    private void on_media_key_pressed(string key)
    {
        unowned List<AppRunner> head = app_runners.head;
        var handled = false;
        foreach (var app_runner in head)
        {
            var app_id = app_runner.app_id;
            if (app_id in clients)
            {
                try
                {
                    var response = app_runner.call_sync("/nuvola/mediakeys/media-key-pressed", new Variant("(s)", key));
                    if (!Drt.variant_bool(response, ref handled))
                    {
                        warning("/nuvola/mediakeys/media-key-pressed got invalid response from %s instance %s: %s\n", Nuvola.get_app_name(), app_id,
                            response == null ? "null" : response.print(true));
                    }
                }
                catch (GLib.Error e)
                {
                    warning("Communication with app runner %s for action %s failed. %s", app_id, key, e.message);
                }

                if (handled)
                    break;
            }
        }

        if (!handled)
            warning("MediaKey %s was not handled by any app runner.", key);
    }
}

} // namespace Nuvola
