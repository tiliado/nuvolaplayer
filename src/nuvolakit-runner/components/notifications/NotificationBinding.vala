/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class Nuvola.NotificationBinding: ObjectBinding<NotificationInterface> {
    public NotificationBinding(Drt.RpcRouter router, WebWorker web_worker) {
        base(router, web_worker, "Nuvola.Notification");
    }

    protected override void bind_methods() {
        bind("update", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Update notification.",
            handle_update, {
                new Drt.StringParam("name", true, false, null, "Notification name."),
                new Drt.StringParam("title", true, false, null, "Notification title."),
                new Drt.StringParam("message", true, false, null, "Notification message."),
                new Drt.StringParam("icon-name", false, true, null, "Notification icon name."),
                new Drt.StringParam("icon-path", false, true, null, "Notification icon path."),
                new Drt.BoolParam("resident", false, false, "Whether the notification is resident."),
                new Drt.StringParam("category", false, true, null, "Notification category."),
            });
        bind("set-actions", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set notification actions.",
            handle_set_actions, {
                new Drt.StringParam("name", true, false, null, "Notification name."),
                new Drt.StringArrayParam("actions", true, null, "Notification actions.")
            });
        bind("remove-actions", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Remove notification actions.",
            handle_remove_actions, {
                new Drt.StringParam("name", true, false, null, "Notification name.")
            });
        bind("show", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Show notification.",
            handle_show, {
                new Drt.StringParam("name", true, false, null, "Notification name."),
                new Drt.BoolParam("force", false, false, "Make sure the notification is shown.")
            });
    }

    private void handle_update(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        string? name = request.pop_string();
        string? title = request.pop_string();
        string? message = request.pop_string();
        string? icon_name = request.pop_string();
        string? icon_path = request.pop_string();
        bool resident = request.pop_bool();
        string? category = request.pop_string();
        foreach (var object in objects) {
            if (object.update(name, title, message, icon_name, icon_path, resident, category)) {
                break;
            }
        }
        request.respond(null);
    }

    private void handle_set_actions(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        string? name = request.pop_string();
        string[] actions = request.pop_strv();
        foreach (NotificationInterface object in objects) {
            if (object.set_actions(name, (owned) actions)) {
                break;
            }
        }
        request.respond(null);
    }

    private void handle_remove_actions(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        string? name = request.pop_string();
        foreach (NotificationInterface object in objects) {
            if (object.remove_actions(name)) {
                break;
            }
        }
        request.respond(null);
    }

    private void handle_show(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        string? name = request.pop_string();
        bool force = request.pop_bool();
        foreach (NotificationInterface object in objects) {
            if (object.show(name, force)) {
                break;
            }
        }
        request.respond(null);
    }
}
