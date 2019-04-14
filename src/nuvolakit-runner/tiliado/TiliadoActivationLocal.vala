/*
 * Copyright 2017-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class TiliadoActivation : GLib.Object {
    private const string TILIADO_ACCOUNT_TOKEN_TYPE = "tiliado.account2.token_type";
    private const string TILIADO_ACCOUNT_ACCESS_TOKEN = "tiliado.account2.access_token";
    private const string TILIADO_ACCOUNT_REFRESH_TOKEN = "tiliado.account2.refresh_token";
    private const string TILIADO_ACCOUNT_SCOPE = "tiliado.account2.scope";
    private const string TILIADO_ACCOUNT_MEMBERSHIP = "tiliado.account2.membership";
    private const string TILIADO_ACCOUNT_USER = "tiliado.account2.user";
    private const string TILIADO_ACCOUNT_EXPIRES = "tiliado.account2.expires";
    private const string TILIADO_ACCOUNT_SIGNATURE = "tiliado.account2.signature";
    private const string TILIADO_TRIAL = "tiliado.trial";
    private const string TILIADO_TRIAL_SIGNATURE = "tiliado.trial_signature";

    public static TiliadoActivation? create_if_enabled(Drt.KeyValueStorage config) {
        #if TILIADO_API
        assert(TILIADO_OAUTH2_CLIENT_ID != null && TILIADO_OAUTH2_CLIENT_ID[0] != '\0');
        var tiliado = new TiliadoApi2(
            TILIADO_OAUTH2_CLIENT_ID, Drt.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data),
            TILIADO_OAUTH2_API_ENDPOINT, TILIADO_OAUTH2_TOKEN_ENDPOINT, null, "nuvolaplayer");
        return new TiliadoActivation(tiliado, config);
        #else
        return null;
        #endif
    }

    public TiliadoApi2 tiliado {get; construct;}
    public Drt.KeyValueStorage config {get; construct;}
    private TiliadoApi2.User? cached_user = null;
    private MachineTrial? cached_trial = null;
    private uint update_timeout = 0;
    private uint trial_update_timeout = 0;

    public TiliadoActivation(TiliadoApi2 tiliado, Drt.KeyValueStorage config) {
        GLib.Object(tiliado: tiliado, config: config);
    }

    construct {
        tiliado.notify["token"].connect_after(on_api_token_changed);
        tiliado.notify["user"].connect_after(on_api_user_changed);
        tiliado.device_code_grant_started.connect(on_device_code_grant_started);
        tiliado.device_code_grant_error.connect(on_device_code_grant_error);
        tiliado.device_code_grant_cancelled.connect(on_device_code_grant_cancelled);
        tiliado.device_code_grant_finished.connect(on_device_code_grant_finished);
        load_cached_data();
        load_cached_trial();
        config.changed.connect(on_config_changed);
    }

    ~TiliadoActivation() {
        config.changed.disconnect(on_config_changed);
        tiliado.notify["token"].disconnect(on_api_token_changed);
        tiliado.notify["user"].disconnect(on_api_user_changed);
        tiliado.device_code_grant_started.disconnect(on_device_code_grant_started);
        tiliado.device_code_grant_error.disconnect(on_device_code_grant_error);
        tiliado.device_code_grant_cancelled.disconnect(on_device_code_grant_cancelled);
        tiliado.device_code_grant_finished.disconnect(on_device_code_grant_finished);
    }

    public signal void trial_updated(MachineTrial? trial);

    public signal void user_info_updated(TiliadoApi2.User? user);

    public signal void activation_started(string url);

    public virtual signal void activation_failed(string error) {
        warning("Tiliado Activation failed: %s", error);
    }

    public signal void activation_cancelled();

    public signal void activation_finished(TiliadoApi2.User? user);

    public bool has_user_membership(TiliadoMembership membership) {
        return get_membership() >= membership;
    }

    public TiliadoMembership get_membership() {
        TiliadoApi2.User user = get_user_info();
        if (user != null) {
            return TiliadoMembership.from_uint(user.membership);
        }
        return TiliadoMembership.NONE;
    }

    public TiliadoApi2.User? get_user_info() {
        return cached_user;
    }

    public void update_user_info() {
        tiliado.fetch_current_user.begin(on_update_current_user_done);
    }

    public void start_activation() {
        tiliado.start_device_code_grant(TILIADO_OAUTH2_DEVICE_CODE_ENDPOINT);
    }

    public void cancel_activation() {
        tiliado.cancel_device_code_grant();
    }

    public void drop_activation() {
        tiliado.drop_token();
        cache_user(null);
        user_info_updated(null);
    }

    public TiliadoApi2.User? update_user_info_sync() {
        if (tiliado.token == null) {
            return null;
        } else {
            return update_user_info_sync_internal();
        }
    }

    public MachineTrial? get_machine_trial() {
        return cached_trial;
    }

    public async MachineTrial? get_fresh_machine_trial() throws Oauth2Error {
        MachineTrial? trial =  yield tiliado.get_trial_for_machine(yield Nuvola.get_machine_hash());
        cache_trial(trial);
        return trial;
    }

    public async bool start_trial() throws Oauth2Error {
        MachineTrial? trial =  yield tiliado.start_trial_for_machine(yield Nuvola.get_machine_hash());
        if (trial != null) {
            cache_trial(trial);
            return true;
        }
        return false;
    }

    protected TiliadoApi2.User? update_user_info_sync_internal() {
        TiliadoApi2.User? user = null;
        var loop = new MainLoop();
        ulong handler_id = user_info_updated.connect((o, u) => {
            user = u;
            loop.quit();
        });
        update_user_info();
        loop.run();
        disconnect(handler_id);
        return user;
    }

    private void on_device_code_grant_started(string url) {
        activation_started(url);
    }

    private void on_device_code_grant_error(string code, string? message) {
        string detail;
        switch (code) {
        case "parse_error":
        case "response_error":
            detail = "The server returned a malformed response.";
            break;
        case "invalid_client":
        case "unauthorized_client":
            detail = "This build of %s is not authorized to use the Tiliado API.".printf(Nuvola.get_app_name());
            break;
        case "access_denied":
            detail = "The authorization request has been dismissed. Please try again.";
            break;
        case "expired_token":
            detail = "The authorization request has expired. Please try again.";
            break;
        default:
            detail = "%s has sent an invalid request.".printf(Nuvola.get_app_name());
            break;
        }
        activation_failed(detail);
    }

    private void on_device_code_grant_cancelled() {
        activation_cancelled();
    }

    private void on_device_code_grant_finished(Oauth2Token token) {
        tiliado.fetch_current_user.begin(on_get_current_user_for_activation_done);
    }

    private void on_get_current_user_for_activation_done(GLib.Object? o, AsyncResult res) {
        try {
            TiliadoApi2.User? user = tiliado.fetch_current_user.end(res);
            user = user != null && user.is_valid() ? user : null;
            activation_finished(user);
        } catch (Oauth2Error e) {
            string err = "Failed to fetch user's details. " + e.message;
            activation_failed(err);
        }
        cache_user(tiliado.user);
    }

    private void on_update_current_user_done(GLib.Object? o, AsyncResult res) {
        try {
            tiliado.fetch_current_user.end(res);
        } catch (Oauth2Error e) {
            cache_user(null);
            user_info_updated(null);
        }
    }

    private void on_config_changed(string key, Variant? old_value) {
        if (key.has_prefix("tiliado.account2")) {
            if (update_timeout != 0) {
                Source.remove(update_timeout);
            }
            update_timeout = Timeout.add(50, load_from_updated_cache);
        } else if (key.has_prefix("tiliado.trial")) {
            if (trial_update_timeout != 0) {
                Source.remove(trial_update_timeout);
            }
            trial_update_timeout = Timeout.add(50, load_trial_from_updated_cache);
        }
    }

    private bool load_from_updated_cache() {
        update_timeout = 0;
        load_cached_data();
        return false;
    }

    private bool load_trial_from_updated_cache() {
        trial_update_timeout = 0;
        load_cached_trial();
        return false;
    }

    /**
     * Load Oauth2Token and TiliadoApi2.User from configuration.
     * Set both to null if it fails.
     */
    private void load_cached_data() {
        tiliado.notify["token"].disconnect(on_api_token_changed);
        bool user_valid = false;
        if (config.has_key(TILIADO_ACCOUNT_ACCESS_TOKEN)) {
            tiliado.token = new Oauth2Token(
                config.get_string(TILIADO_ACCOUNT_ACCESS_TOKEN),
                config.get_string(TILIADO_ACCOUNT_REFRESH_TOKEN),
                config.get_string(TILIADO_ACCOUNT_TOKEN_TYPE),
                config.get_string(TILIADO_ACCOUNT_SCOPE));

            string? signature = config.get_string(TILIADO_ACCOUNT_SIGNATURE);
            if (signature != null) {
                int64 expires = config.get_int64(TILIADO_ACCOUNT_EXPIRES);
                string? user_name = config.get_string(TILIADO_ACCOUNT_USER);
                uint membership = (uint) config.get_int64(TILIADO_ACCOUNT_MEMBERSHIP);
                string user_info_str = concat_tiliado_user_info(user_name, membership, expires);
                if (expires >= new DateTime.now_utc().to_unix()
                && tiliado.hmac_sha1_verify_string(user_info_str, signature)) {
                    var user = new TiliadoApi2.User(0, null, user_name, true, true, new int[] {});
                    user.membership = membership;
                    cached_user = user;
                    user_valid = true;
                }
            }
        } else {
            tiliado.token = null;
        }
        if (!user_valid) {
            cached_user = null;
        }
        user_info_updated(cached_user);
        tiliado.notify["token"].connect_after(on_api_token_changed);
    }

    private void load_cached_trial() {
        string? trial_json = config.get_string(TILIADO_TRIAL);
        string? trial_signature = config.get_string(TILIADO_TRIAL_SIGNATURE);
        if (Drt.String.is_empty(trial_json) || Drt.String.is_empty(trial_signature) ||
            !tiliado.hmac_sha1_verify_string(trial_json, trial_signature)) {
            cached_trial = null;
        } else {
            cached_trial = new MachineTrial.from_string(trial_json);
        }
        trial_updated(cached_trial);
    }

    private void cache_trial(MachineTrial? trial) {
        this.cached_trial = trial;
        config.changed.disconnect(on_config_changed);
        if (trial == null) {
            config.unset(TILIADO_TRIAL);
            config.unset(TILIADO_TRIAL_SIGNATURE);
        } else {
            string trial_json = trial.to_string();
            config.set_string(TILIADO_TRIAL, trial_json);
            config.set_string(TILIADO_TRIAL_SIGNATURE, tiliado.hmac_sha1_for_string(trial_json));
        }
        config.changed.connect(on_config_changed);
        trial_updated(trial);
    }

    /**
     * Store it to configuration.
     */
    private void on_api_user_changed(GLib.Object o, ParamSpec p) {
        TiliadoApi2.User user = tiliado.user;
        cache_user(user);
        user_info_updated(user);
    }

    /**
     * Store TiliadoApi2.User into configuration if it is valid, remove it from configuration otherwise.
     * If user is valid, it is saved as this.cached_user, otherwise it is set to null.
     * Note that config change callback is temporarily disabled.
     */
    private void cache_user(TiliadoApi2.User? user) {
        config.changed.disconnect(on_config_changed);
        if (user != null && user.is_valid()) {
            int64 expires = new DateTime.now_utc().add_weeks(5).to_unix();
            config.set_string(TILIADO_ACCOUNT_USER, user.name);
            config.set_int64(TILIADO_ACCOUNT_MEMBERSHIP, (int64) user.membership);
            config.set_int64(TILIADO_ACCOUNT_EXPIRES, expires);
            string signature = tiliado.hmac_sha1_for_string(
                concat_tiliado_user_info(user.name, user.membership, expires));
            config.set_string(TILIADO_ACCOUNT_SIGNATURE, signature);
            cached_user = user;
        } else {
            config.unset(TILIADO_ACCOUNT_USER);
            config.unset(TILIADO_ACCOUNT_MEMBERSHIP);
            config.unset(TILIADO_ACCOUNT_EXPIRES);
            config.unset(TILIADO_ACCOUNT_SIGNATURE);
            cached_user = null;
        }
        config.changed.connect(on_config_changed);
    }

    /**
     * Store the token to configuration.
     * Note that config change callback is temporarily disabled.
     */
    private void on_api_token_changed(GLib.Object o, ParamSpec p) {
        Oauth2Token token = tiliado.token;
        config.changed.disconnect(on_config_changed);
        if (token != null) {
            config.set_value(TILIADO_ACCOUNT_TOKEN_TYPE, token.token_type);
            config.set_value(TILIADO_ACCOUNT_ACCESS_TOKEN, token.access_token);
            config.set_value(TILIADO_ACCOUNT_REFRESH_TOKEN, token.refresh_token);
            config.set_value(TILIADO_ACCOUNT_SCOPE, token.scope);
        } else {
            config.unset(TILIADO_ACCOUNT_TOKEN_TYPE);
            config.unset(TILIADO_ACCOUNT_ACCESS_TOKEN);
            config.unset(TILIADO_ACCOUNT_REFRESH_TOKEN);
            config.unset(TILIADO_ACCOUNT_SCOPE);
        }
        config.changed.connect(on_config_changed);
    }

    private inline string concat_tiliado_user_info(string name, uint membership_rank, int64 expires) {
        return "%s:%u:%s".printf(name, membership_rank, expires.to_string());
    }
}

} // namespace Nuvola
