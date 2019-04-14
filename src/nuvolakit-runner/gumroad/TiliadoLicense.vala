/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class TiliadoLicense {
    private const string KEY_GUMROAD = "gumroad";
    private const string KEY_TIER = "tier";
    private const string KEY_VALID = "valid";
    public bool valid {get; private set;}
    public GumroadLicense license {get; private set;}
    public TiliadoMembership license_tier {get; private set;}
    public TiliadoMembership effective_tier {get; private set;}

    public TiliadoLicense(GumroadLicense license, TiliadoMembership tier, bool valid) {
        this.valid = valid;
        this.license = license;
        this.license_tier = tier;
        this.effective_tier = valid ? tier : TiliadoMembership.NONE;
    }

    public TiliadoLicense.from_json(Drt.JsonObject json) {
        this(
            new GumroadLicense.from_json(json.get_object(KEY_GUMROAD)),
            TiliadoMembership.from_int(json.get_int_or(KEY_TIER, 0)),
            json.get_bool_or(KEY_VALID, false));
    }

    public TiliadoLicense.from_string(string json) throws Drt.JsonError {
        this.from_json(Drt.JsonParser.load_object(json));
    }

    public bool is_valid() {
        return valid;
    }

    public unowned string? get_reason() {
        if (license.refunded) {
            return "The license has been refunded.";
        }
        if (license.chargebacked) {
            return "The license has been chargebacked.";
        }
        if (license.cancelled_at != null) {
            return "The license subscription has been cancelled.";
        }
        if (license.failed_at != null) {
            return "The payment for the license subscription has failed.";
        }
        return null;
    }

    public Drt.JsonBuilder to_json() {
        var builder = new Drt.JsonBuilder();
        builder.begin_object();
        builder.set_member(KEY_GUMROAD).add(license.to_json().root);
        builder.set_int(KEY_TIER, (int) license_tier);
        builder.set_bool(KEY_VALID, valid);
        builder.end_object();
        return builder;
    }

    public string to_string() {
        return to_json().to_pretty_string();
    }

    public string to_compact_string() {
        return to_json().to_compact_string();
    }
}

} // namespace Nuvola
