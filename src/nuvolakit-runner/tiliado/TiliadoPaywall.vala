/*
 * Copyright 2018-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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
    public TiliadoMembership tier {get; private set; default = TiliadoMembership.BASIC;}
    public bool unlocked {get; private set; default = false;}
    private TiliadoGumroad gumroad;
    private Drtgtk.Application app;

    public TiliadoPaywall(Drtgtk.Application app, TiliadoGumroad gumroad) {
        this.gumroad = gumroad;
        this.app = app;
        gumroad.notify["cached-license"].connect_after(on_gumroad_license_changed);
        update_tier_info();
    }

    ~TiliadoPaywall() {
        gumroad.notify["cached-license"].disconnect(on_gumroad_license_changed);
    }

    public signal void tier_info_updated();

    public signal void verifying_gumroad_license();

    public signal void gumroad_license_verification_failed(string? reason);

    public signal void gumroad_license_invalid();

    public bool has_tier(TiliadoMembership tier) {
        return this.tier >= tier;
    }


    public TiliadoLicense? get_gumroad_license() {
        return gumroad.cached_license;
    }

    public bool has_gumroad_license() {
        return get_gumroad_license() != null;
    }

    public TiliadoMembership get_gumroad_license_tier() {
        return gumroad.get_tier();
    }

    public async void refresh_data() {
        if (gumroad.needs_refresh) {
            gumroad.refresh_license_sync();
        }
        update_tier_info();
    }

    public void show_help_page() {
        app.show_uri("https://nuvola.tiliado.eu/docs/4/activation/");
    }

    public void open_purchase_page() {
        app.show_uri("https://nuvola.tiliado.eu/pricing/");
    }

    public void open_upgrade_page() {
        app.show_uri("https://nuvola.tiliado.eu/pricing/#upgrade");
    }

    private void update_tier_info() {
        TiliadoMembership result = TiliadoMembership.BASIC;
        TiliadoMembership candidate = TiliadoMembership.NONE;
        if ((candidate = gumroad.get_tier()) > result) {
            result = candidate;
        }
        unlocked = result > TiliadoMembership.NONE;
        this.tier = result;
        tier_info_updated();
    }

    // Gumroad license

    public void drop_gumroad_license() {
        gumroad.drop_license();
        update_tier_info();
    }

    public void verify_gumroad_license(string key) {
        verifying_gumroad_license();
        TiliadoLicense? old_license = get_gumroad_license();
        bool increase = old_license == null || old_license.license.uses < 1 || old_license.license.license_key  != key;
        gumroad.verify_license.begin(key, increase, on_gumroad_license_verified);
    }

    private void on_gumroad_license_verified(GLib.Object? o, AsyncResult res) {
        TiliadoLicense? license;
        bool success;
        try {
            success = gumroad.verify_license.end(res, out license);
        } catch (GumroadError e) {
            gumroad_license_verification_failed(e.message);
            return;
        }
        if (success) {
            update_tier_info();
        } else {
            gumroad_license_invalid();
        }
    }

    private void on_gumroad_license_changed(GLib.Object emitter, ParamSpec param) {
        update_tier_info();
    }
}

} // namespace Nuvola
