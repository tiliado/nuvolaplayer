/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class ActionsKeyBinderServer : GLib.Object
{
    private Drt.RpcBus ipc_bus;
    private ActionsKeyBinder keybinder;
    private unowned Queue<AppRunner> app_runners;

    public class ActionsKeyBinderServer(Drt.RpcBus ipc_bus, ActionsKeyBinder keybinder, Queue<AppRunner> app_runners)
    {
        this.ipc_bus = ipc_bus;
        this.keybinder = keybinder;
        this.app_runners = app_runners;
        keybinder.action_activated.connect(on_action_activated);
        var router = ipc_bus.router;
        router.add_method("/nuvola/actionkeybinder/get-keybinding", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_get_keybinding, {
                new Drt.StringParam("action", true, false)
            });
        router.add_method("/nuvola/actionkeybinder/set-keybinding", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_set_keybinding, {
                new Drt.StringParam("action", true, false),
                new Drt.StringParam("keybinding", true, true),
            });
        router.add_method("/nuvola/actionkeybinder/bind", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_bind, {
                new Drt.StringParam("action", true, false),
            });
        router.add_method("/nuvola/actionkeybinder/unbind", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_unbind, {
                new Drt.StringParam("action", true, false),
            });
        router.add_method("/nuvola/actionkeybinder/is-available", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_is_available, {
                new Drt.StringParam("keybinding", true, false),
            });
        router.add_method("/nuvola/actionkeybinder/get-action", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_get_action, {
                new Drt.StringParam("keybinding", true, false),
            });
    }

    private void handle_get_keybinding(Drt.RpcRequest request) throws Drt.RpcError
    {
        var action = request.pop_string();
        request.respond(new Variant("ms", keybinder.get_keybinding(action)));
    }

    private void handle_set_keybinding(Drt.RpcRequest request) throws Drt.RpcError
    {
        var action = request.pop_string();
        var keybinding = request.pop_string();
        request.respond(new Variant.boolean(keybinder.set_keybinding(action, keybinding)));
    }

    private void handle_bind(Drt.RpcRequest request) throws Drt.RpcError
    {
        var action = request.pop_string();
        request.respond(new Variant.boolean(keybinder.bind(action)));
    }

    private void handle_unbind(Drt.RpcRequest request) throws Drt.RpcError
    {
        var action = request.pop_string();
        request.respond(new Variant.boolean(keybinder.unbind(action)));
    }

    private void handle_get_action(Drt.RpcRequest request) throws Drt.RpcError
    {
        var keybinding = request.pop_string();
        request.respond(new Variant("ms", keybinder.get_action(keybinding)));
    }

    private void handle_is_available(Drt.RpcRequest request) throws Drt.RpcError
    {
        var keybinding = request.pop_string();
        request.respond(new Variant.boolean(keybinder.is_available(keybinding)));
    }

    private void on_action_activated(string name)
    {
        unowned List<AppRunner> head = app_runners.head;
        var handled = false;
        foreach (var app_runner in head)
        {
            try
            {
                var response = app_runner.call_sync("/nuvola/actionkeybinder/action-activated", new Variant("(s)", name));
                if (!Drt.variant_bool(response, ref handled))
                {
                    warning("Got invalid response from %s instance %s: %s\n", Nuvola.get_app_name(), app_runner.app_id,
                        response == null ? "null" : response.print(true));
                }
                else if(handled)
                {
                    debug("Action %s was handled in %s.", name, app_runner.app_id);
                    break;
                }
            }
            catch (GLib.Error e)
            {
                warning("Communication with app runner %s for action %s failed. %s", app_runner.app_id, name, e.message);
            }
        }

        if (!handled)
        warning("Action %s was not handled by any app runner.", name);
    }
}

} // namespace Nuvola
