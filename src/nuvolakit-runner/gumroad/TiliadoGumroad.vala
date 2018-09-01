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

public class TiliadoGumroad : GLib.Object {
    private const string TILIADO_GUMROAD_LICENSE = "tiliado.gumroad.license";
    private const string TILIADO_GUMROAD_EXPIRES = "tiliado.gumroad.expires";
    private const string TILIADO_GUMROAD_SIGNATURE = "tiliado.gumroad.signature";

    public TiliadoLicense? cached_license {get; private set; default = null;}
    public string? cached_license_key {get; private set; default = null;}
    public bool needs_refresh {get {return cached_license_key != null;}}
    private Drt.KeyValueStorage config;
    private string sign_key;
    private static string[] basic_products;
    private static string[] premium_products;
    private static string[] patron_products;
    private bool ignore_config_changed = false;
    private GumroadApi gumroad;
    private TiliadoApi2 tiliado;

    static construct {
        basic_products = {"nuvolabasic"};
        premium_products = {"nuvolapremium"};
        patron_products = {"nuvolapatron"};
    }

    public TiliadoGumroad(Drt.KeyValueStorage config, string sign_key, TiliadoApi2 tiliado, GumroadApi? gumroad=null) {
        this.config = config;
        this.sign_key = sign_key;
        this.gumroad = gumroad ?? new GumroadApi(null);
        this.tiliado = tiliado;
        load_cached_data();
        config.changed.connect(on_config_changed);
    }

    ~TiliadoGumroad() {
        config.changed.disconnect(on_config_changed);
    }

    public async bool verify_license(
        string license_key, bool increment_uses_count, out TiliadoLicense license
    ) throws Oauth2Error {
        foreach (unowned string product_id in patron_products) {
            license = yield get_license(product_id, license_key, TiliadoMembership.PATRON, increment_uses_count);
            if (license != null) {
                cache_license(license);
                return true;
            }
        }
        foreach (unowned string product_id in premium_products) {
            license = yield get_license(product_id, license_key, TiliadoMembership.PREMIUM, increment_uses_count);
            if (license != null) {
                cache_license(license);
                return true;
            }
        }
        foreach (unowned string product_id in basic_products) {
            license = yield get_license(product_id, license_key, TiliadoMembership.BASIC, increment_uses_count);
            if (license != null) {
                cache_license(license);
                return true;
            }
        }
        license = null;
        return false;
    }

    private async TiliadoLicense? get_license(
        string product_id, string license_key, TiliadoMembership tier, bool increment_uses_count
    ) throws Oauth2Error {
        try {
            GumroadLicense? license = yield gumroad.get_license(product_id, license_key, increment_uses_count);
            bool valid = license.valid;
            if (!valid && license.is_invalid_due_to_cancelled_subscription()) {
                valid = yield tiliado.is_gumroad_key_still_valid(license_key);
            }
            return new TiliadoLicense(license, tier, valid);
        } catch (Oauth2Error e) {
            if (!(e is Oauth2Error.HTTP_NOT_FOUND)) {
                throw e;
            }
        }
        return null;
    }

    public void cache_license(TiliadoLicense license) {
        cached_license = license;
        cached_license_key = null;
        int64 expires = new DateTime.now_utc().add_weeks(4).to_unix();
        string license_json = license.to_compact_string();
        ignore_config_changed = true;
        config.set_string(TILIADO_GUMROAD_LICENSE, license_json);
        config.set_int64(TILIADO_GUMROAD_EXPIRES, expires);
        string signature = Hmac.sha1_for_string(sign_key, concat_gumroad_info(license_json, expires));
        config.set_string(TILIADO_GUMROAD_SIGNATURE, signature);
        ignore_config_changed = false;
    }

    public void drop_license() {
        cached_license = null;
        cached_license_key = null;
        ignore_config_changed = true;
        config.unset(TILIADO_GUMROAD_LICENSE);
        config.unset(TILIADO_GUMROAD_EXPIRES);
        config.unset(TILIADO_GUMROAD_SIGNATURE);
        ignore_config_changed = false;
    }

    public TiliadoMembership get_tier() {
        return cached_license != null ? cached_license.effective_tier : TiliadoMembership.NONE;
    }

    public bool has_tier(TiliadoMembership tier) {
        return get_tier() >= tier;
    }

    private void load_cached_data() {
        if (config.has_key(TILIADO_GUMROAD_SIGNATURE)) {
            string? signature = config.get_string(TILIADO_GUMROAD_SIGNATURE);
            string? license_json = config.get_string(TILIADO_GUMROAD_LICENSE);
            if (signature != null && license_json != null) {
                int64 expires = config.get_int64(TILIADO_GUMROAD_EXPIRES);
                string gumroad_info_str = concat_gumroad_info(license_json, expires);
                try {
                    var license = new TiliadoLicense.from_string(license_json);
                    if (expires >= new DateTime.now_utc().to_unix()
                    && Hmac.sha1_verify_string(sign_key, gumroad_info_str, signature)) {
                        cached_license = license;
                        cached_license_key = null;
                    } else {
                        /* Needs refresh */
                        cached_license = null;
                        cached_license_key = license.license.license_key;
                    }
                    return;
                } catch (Drt.JsonError e) {
                    warning("Failed to load cached license: %s", e.message);
                }
            }
        }
        cached_license = null;
        cached_license_key  = null;
    }

    public async bool refresh_license() {
        if (cached_license != null) {
            cached_license_key = cached_license.license.license_key;
        }
        if (cached_license_key == null) {
            return false;
        }
        try {
            TiliadoLicense? license = null;
            yield verify_license(cached_license_key, false, out license);
            if (license != null) {
                return true;
            }
        } catch (Oauth2Error e) {
            warning("Failed to verify the license key: %s", e.message);
        }
        return false;
    }

    public bool refresh_license_sync() {
        var loop = new MainLoop();
        bool result = false;
        refresh_license.begin((o, res) => {result = refresh_license.end(res); loop.quit();});
        loop.run();
        return result;
    }

    private string concat_gumroad_info(string? license_json, int64 expires) {
        return "%s:%s".printf(license_json, expires.to_string());
    }

    private void on_config_changed(string key) {
        if (ignore_config_changed) {
            return;
        }
        switch (key) {
        case TILIADO_GUMROAD_SIGNATURE:
        case TILIADO_GUMROAD_EXPIRES:
        case TILIADO_GUMROAD_LICENSE:
            load_cached_data();
            break;
        }
    }
}

} // namespace Nuvola
