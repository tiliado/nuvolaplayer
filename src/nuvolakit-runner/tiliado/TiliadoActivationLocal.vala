/*
 * Copyright 2017-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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
    private const string TILIADO_TRIAL = "tiliado.trial";
    private const string TILIADO_TRIAL_SIGNATURE = "tiliado.trial_signature";

    public static TiliadoActivation? create_if_enabled(Drt.KeyValueStorage config) {
        #if TILIADO_API
        var tiliado = new TiliadoApi2(
            TILIADO_OAUTH2_API_ENDPOINT,
            Drt.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data),
            "nuvolaplayer"
        );
        return new TiliadoActivation(tiliado, config);
        #else
        return null;
        #endif
    }

    public TiliadoApi2 tiliado {get; construct;}
    public Drt.KeyValueStorage config {get; construct;}
    private MachineTrial? cached_trial = null;
    private uint trial_update_timeout = 0;

    public TiliadoActivation(TiliadoApi2 tiliado, Drt.KeyValueStorage config) {
        GLib.Object(tiliado: tiliado, config: config);
    }

    construct {
        load_cached_trial();
        config.changed.connect(on_config_changed);
    }

    ~TiliadoActivation() {
        config.changed.disconnect(on_config_changed);
    }

    public signal void trial_updated(MachineTrial? trial);

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

    private void on_config_changed(string key, Variant? old_value) {
        if (key.has_prefix("tiliado.trial")) {
            if (trial_update_timeout != 0) {
                Source.remove(trial_update_timeout);
            }
            trial_update_timeout = Timeout.add(50, load_trial_from_updated_cache);
        }
    }

    private bool load_trial_from_updated_cache() {
        trial_update_timeout = 0;
        load_cached_trial();
        return false;
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
}

} // namespace Nuvola
