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

public class Nuvola.LauncherBinding: ModelBinding<LauncherModel> {
    public LauncherBinding(Drt.RpcRouter router, WebWorker web_worker, LauncherModel? model=null) {
        base(router, web_worker, "Nuvola.Launcher", model ?? new LauncherModel());
    }

    protected override void bind_methods() {
        bind("set-tooltip", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set launcher tooltip.",
            handle_set_tooltip, {
                new Drt.StringParam("text", true, false, null, "Tooltip text.")
            });
        bind("set-actions", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set launcher actions.",
            handle_set_actions, {
                new Drt.StringArrayParam("actions", true, null, "Action name.")
            });
        bind("add-action", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Add launcher action.",
            handle_add_action, {
                new Drt.StringParam("name", true, false, null, "Action name.")
            });
        bind("remove-action", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Remove launcher action.",
            handle_remove_action, {
                new Drt.StringParam("name", true, false, null, "Action name.")
            });
        bind("remove-actions", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Remove all launcher actions.",
            handle_remove_actions, null);
    }

    private void handle_set_tooltip(Drt.RpcRequest request) throws Drt.RpcError {
        model.tooltip = request.pop_string();
        request.respond(null);
    }

    private void handle_add_action(Drt.RpcRequest request) throws Drt.RpcError {
        model.add_action(request.pop_string());
        request.respond(null);
    }

    private void handle_remove_action(Drt.RpcRequest request) throws Drt.RpcError {
        model.remove_action(request.pop_string());
        request.respond(null);
    }

    private void handle_set_actions(Drt.RpcRequest request) throws Drt.RpcError {
        model.actions = request.pop_str_list();
        request.respond(null);
    }

    private void handle_remove_actions(Drt.RpcRequest request) throws Drt.RpcError {
        model.remove_actions();
        request.respond(null);
    }
}
