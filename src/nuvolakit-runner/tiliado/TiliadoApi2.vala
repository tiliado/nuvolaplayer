/*
 * Copyright 2016-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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

public enum TiliadoMembership {
    NONE = 0,
    BASIC = 1,
    PREMIUM = 2,
    PREMIUM_PLUS = 3,
    PATRON = 4,
    PATRON_PLUS = 5,
    DEVELOPER = 6;

    public string get_label() {
        switch (this) {
        case NONE:
            return "Free";
        case BASIC:
            return "Basic";
        case PREMIUM:
            return "★ Premium";
        case PREMIUM_PLUS:
            return "★ Premium+";
        case PATRON:
            return "★ Patron";
        case PATRON_PLUS:
            return "★ Patron+";
        default:
            return "☢ Developer";
        }
    }

    public static TiliadoMembership from_uint(uint level) {
        return (level > DEVELOPER) ? DEVELOPER : (TiliadoMembership) level;
    }

    public static TiliadoMembership from_int(int level) {
        if (level < 0) {
            level = 0;
        }
        return from_uint((uint) level);
    }
}


public class TiliadoApi2 : HttpClient {
    private string? client_secret;
    private string project_id;

    public TiliadoApi2(string api_endpoint, string client_secret, string project_id) {
        base(api_endpoint, true);
        this.client_secret = client_secret;
        this.project_id = project_id;
    }

    public string? hmac_sha1_for_string(string data) {
        return client_secret != null ? Hmac.for_string(ChecksumType.SHA1, client_secret, data) : null;
    }

    public string? hmac_for_string(ChecksumType checksum, string data) {
        return client_secret != null ? Hmac.for_string(checksum, client_secret, data) : null;
    }

    public bool hmac_sha1_verify_string(string data, string hmac) {
        return client_secret != null ? Hmac.verify_string(ChecksumType.SHA1, client_secret, data, hmac) : false;
    }

    public bool hmac_verify_string(ChecksumType checksum, string data, string hmac) {
        return client_secret != null ? Hmac.verify_string(checksum, client_secret, data, hmac): false;
    }

    protected async Drt.JsonObject fetch_json(HttpRequest request) throws Oauth2Error {
        if (!yield request.send()) {
            if (request.is_network_error()) {
                throw new Oauth2Error.NETWORK_ERROR(request.get_reason());
            }
            switch (request.status_code) {
            case 404:
                throw new Oauth2Error.HTTP_NOT_FOUND(request.get_reason());
            case 401:
            case 403:
                throw new Oauth2Error.HTTP_UNAUTHORIZED(request.get_reason());
            default:
                throw new Oauth2Error.HTTP_ERROR(request.get_reason());
            }
        }
        try {
            return request.get_json_object();
        } catch (Drt.JsonError e) {
            throw new Oauth2Error.PARSE_ERROR(Drt.error_to_string(e));
        }
    }

    public async MachineTrial? get_trial_for_machine(string machine) throws Oauth2Error {
        if (project_id == null) {
            return null;
        }
        debug("Get trial for machine: %s/%s", project_id, machine);
        try {
            Drt.JsonObject response = yield fetch_json(
                call("funding/trial_of_machine/%s/%s/".printf(project_id, machine)));
            return new MachineTrial.from_json(response);
        } catch (Oauth2Error e) {
            if (e is Oauth2Error.HTTP_NOT_FOUND) {
                return null;
            }
            throw e;
        }
    }

    public async MachineTrial? start_trial_for_machine(string machine) throws Oauth2Error {
        if (project_id == null) {
            return null;
        }
        debug("Start trial for machine: %s/%s", project_id, machine);
        Drt.JsonObject response = yield fetch_json(
            post("funding/trial_of_machine/%s/%s/".printf(project_id, machine)));
        return new MachineTrial.from_json(response);
    }
}

} // namespace Nuvola
