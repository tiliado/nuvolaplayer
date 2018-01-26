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

namespace Nuvola {

public interface TiliadoActivation : GLib.Object {
    public signal void user_info_updated(TiliadoApi2.User? user);

    public signal void activation_started(string url);

    public virtual signal void activation_failed(string error) {
        warning("Tiliado Activation failed: %s", error);
    }

    public signal void activation_cancelled();

    public signal void activation_finished(TiliadoApi2.User? user);

    public abstract TiliadoApi2.User? get_user_info();

    public abstract void update_user_info();

    public virtual TiliadoApi2.User? update_user_info_sync() {
        return update_user_info_sync_internal();
    }

    protected TiliadoApi2.User? update_user_info_sync_internal() {
        TiliadoApi2.User? user = null;
        var loop = new MainLoop();
        var handler_id = user_info_updated.connect((o, u) => {
            user = u;
            loop.quit();
        });
        update_user_info();
        loop.run();
        disconnect(handler_id);
        return user;
    }

    public abstract void start_activation();

    public abstract void cancel_activation();

    public abstract void drop_activation();

    public bool has_user_membership(TiliadoMembership membership) {
        var user = get_user_info();
        if (user == null)
        return TiliadoMembership.NONE == membership;
        return user.membership >= membership;
    }
}

} // namespace Nuvola
