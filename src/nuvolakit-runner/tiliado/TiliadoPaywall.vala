/*
 * Copyright 2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class TiliadoPaywall : GLib.Object {
    public TiliadoMembership tier {get; private set; default = TiliadoMembership.NONE;}
    public bool unlocked {get; private set; default = false;}
    private TiliadoActivation? tiliado = null;
    private Drtgtk.Application app;
    private bool activation_pending = false;

    public TiliadoPaywall(TiliadoActivation tiliado, Drtgtk.Application app) {
        this.tiliado = tiliado;
        this.app = app;
        tiliado.activation_started.connect(on_activation_started);
        tiliado.activation_failed.connect(on_activation_failed);
        tiliado.activation_finished.connect(on_activation_finished);
        tiliado.user_info_updated.connect(on_user_info_updated);
        update_tier_info();
    }

    ~TiliadoPaywall() {
        tiliado.activation_started.disconnect(on_activation_started);
        tiliado.activation_failed.disconnect(on_activation_failed);
        tiliado.activation_finished.disconnect(on_activation_finished);
        tiliado.user_info_updated.disconnect(on_user_info_updated);
    }

    public signal void tier_info_updated();

    public signal void connecting_tiliado_account();

    public signal void tiliado_account_linking_cancelled();

    public signal void tiliado_account_linking_failed(string message);

    public signal void tiliado_account_linking_finished();

    public bool has_tier(TiliadoMembership tier) {
        return this.tier >= tier;
    }

    public bool have_tiliado_account() {
        return get_tiliado_account() != null;
    }

    public TiliadoApi2.User? get_tiliado_account() {
        return tiliado.get_user_info();
    }

    public TiliadoMembership get_tiliado_account_tier() {
        return tiliado.get_membership();
    }

    public bool has_tiliado_account_tier(TiliadoMembership tier) {
        return tiliado.has_user_membership(tier);
    }

    public bool is_tiliado_developer() {
        return tiliado.has_user_membership(TiliadoMembership.DEVELOPER);
    }

    public bool has_tiliado_account_purchases() {
        return tiliado.has_user_membership(TiliadoMembership.BASIC);
    }

    public void refresh() {
        if (tiliado.get_user_info() == null) {
            tiliado.update_user_info_sync();
        }
        update_tier_info();
    }

    public void show_help_page() {
        // FIXME: activation2.html
        app.show_uri("https://tiliado.github.io/nuvolaplayer/documentation/4/activation.html");
    }

    public void open_purchase_page() {
        app.show_uri("https://nuvola.tiliado.eu/pricing/");
    }

    public void open_tiliado_registration_page() {
        app.show_uri("https://tiliado.eu/accounts/signup/?next=/");
    }

    public void open_upgrade_page() {
        app.show_uri("https://nuvola.tiliado.eu/pricing/#upgrade");
    }

    private void update_tier_info() {
        unlocked = is_tiliado_developer() || has_tiliado_account_purchases();
        TiliadoMembership result = TiliadoMembership.NONE;
        TiliadoMembership candidate = TiliadoMembership.NONE;
        if ((candidate = get_tiliado_account_tier()) > result) {
            result = candidate;
        }
        this.tier = result;
        tier_info_updated();
    }

    // Connect Tiliado account

    public void connect_tiliado_account() {
        tiliado.start_activation();
        activation_pending = true;
        connecting_tiliado_account();
    }

    public void cancel_tiliado_account_linking() {
        tiliado.cancel_activation();
        activation_pending = false;
        tiliado_account_linking_cancelled();
    }

    public void disconnect_tiliado_account() {
        tiliado.drop_activation();
        update_tier_info();
    }

    private void on_activation_started(string uri) {
        app.show_uri(uri);
    }

    private void on_activation_failed(string message) {
        tiliado_account_linking_failed(message);
    }

    private void on_activation_finished(TiliadoApi2.User? user) {
        update_tier_info();
        activation_pending = false;
        tiliado_account_linking_finished();
    }

    private void on_user_info_updated(TiliadoApi2.User? user) {
        if (!activation_pending) {
            update_tier_info();
        }
    }
}

} // namespace Nuvola
