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

public class Nuvola.NotificationsBinding: ObjectBinding<NotificationsInterface> {
    public NotificationsBinding(Drt.RpcRouter router, WebWorker web_worker) {
        base(router, web_worker, "Nuvola.Notifications");
    }

    protected override void bind_methods() {
        bind("show-notification", Drt.RpcFlags.WRITABLE,
            "Show notification.",
            handle_show_notification, {
                new Drt.StringParam("title", true, false, null, "Notification title."),
                new Drt.StringParam("message", true, false, null, "Notification message."),
                new Drt.StringParam("icon-name", false, true, null, "Notification icon name."),
                new Drt.StringParam("icon-path", false, true, null, "Notification icon path."),
                new Drt.BoolParam("force", false, false, "Make sure the notification is shown."),
                new Drt.StringParam("category", true, false, null, "Notification category.")
            });
        bind("is-persistence-supported", Drt.RpcFlags.READABLE,
            "returns true if persistence is supported.",
            handle_is_persistence_supported, null);
    }

    private void handle_show_notification(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        string? title = request.pop_string();
        string? message = request.pop_string();
        string? icon_name = request.pop_string();
        string? icon_path = request.pop_string();
        bool force = request.pop_bool();
        string? category = request.pop_string();
        foreach (NotificationsInterface object in objects)
        if (object.show_anonymous(title, message, icon_name, icon_path, force, category))
        break;
        request.respond(null);
    }

    private void handle_is_persistence_supported(Drt.RpcRequest request) throws Drt.RpcError {
        check_not_empty();
        bool supported = false;
        foreach (NotificationsInterface object in objects)
        if (object.is_persistence_supported(ref supported))
        break;
        request.respond(new Variant.boolean(supported));
    }
}
