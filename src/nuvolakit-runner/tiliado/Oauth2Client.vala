/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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
public errordomain Oauth2Error {
    UNKNOWN,
    PARSE_ERROR,
    RESPONSE_ERROR,
    INVALID_CLIENT,
    INVALID_REQUEST,
    HTTP_ERROR,
    HTTP_NOT_FOUND,
    HTTP_UNAUTHORIZED,
    INVALID_GRANT,
    UNAUTHORIZED_CLIENT,
    UNSUPPORTED_GRANT_TYPE,
    NETWORK_ERROR;
}

public class Oauth2Client : HttpClient {
    private static bool debug_soup;
    public string client_id;
    public string? client_secret;
    public Oauth2Token? token {get; set;}
    public string? token_endpoint;
    private string? device_code_endpoint = null;
    private string? device_code = null;
    private uint device_code_cb_id = 0;

    static construct {
        debug_soup = Environment.get_variable("OAUTH2_DEBUG_SOUP") == "yes";
    }

    public Oauth2Client(string client_id, string? client_secret, string api_endpoint, string? token_endpoint, Oauth2Token? token) {
        base(api_endpoint, debug_soup);
        this.client_id = client_id;
        this.client_secret = client_secret;
        this.token_endpoint = token_endpoint;
        this.token = token;
    }

    public signal void device_code_grant_cancelled();

    public signal void device_code_grant_finished(Oauth2Token token);

    public virtual signal void device_code_grant_started(string verification_uri) {
        debug("Device code grant verification URI: %s", verification_uri);
    }

    public virtual signal void device_code_grant_error(string code, string? description) {
        warning("Device code grant error: %s. %s", code, description ?? "(null)");
    }

    public async bool refresh_token() throws Oauth2Error {
        if (token == null || token.refresh_token == null) {
            return false;
        }
        Soup.Message msg = Soup.Form.request_new("POST", token_endpoint, "grant_type", "refresh_token",
            "refresh_token", token.refresh_token, "client_id", client_id);
        if (client_secret != null) {
            msg.request_headers.replace("Authorization",
                "Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
        }

        Drt.JsonObject? response = null;
        HttpRequest request = create_request(msg);
        if (!yield request.send()) {
            string? error_description;
            switch (parse_error(request, out error_description)) {
            case "invalid_request":
                token = null;
                throw new Oauth2Error.INVALID_REQUEST(error_description);
            case "invalid_grant":
                token = null;
                throw new Oauth2Error.INVALID_GRANT(error_description);
            case "invalid_client":
                token = null;
                throw new Oauth2Error.INVALID_CLIENT(error_description);
            case "unauthorized_client":
                token = null;
                throw new Oauth2Error.UNAUTHORIZED_CLIENT(error_description);
            case "unsupported_grant_type":
                token = null;
                throw new Oauth2Error.UNSUPPORTED_GRANT_TYPE(error_description);
            default:
                switch (request.status_code) {
                case 404:
                    throw new Oauth2Error.HTTP_NOT_FOUND("%s. %u: %s".printf(
                        error_description, msg.status_code, Soup.Status.get_phrase(msg.status_code)));
                default:
                    throw new Oauth2Error.UNKNOWN("%s. %u: %s".printf(
                        error_description, msg.status_code, Soup.Status.get_phrase(msg.status_code)));
                }
            }
        }

        try {
            response = request.get_json_object();
        } catch (Drt.JsonError e) {
            throw new Oauth2Error.PARSE_ERROR(Drt.error_to_string(e));
        }
        string? access_token;
        response.get_string("access_token", out access_token);
        string? refresh_token;
        response.get_string("refresh_token", out refresh_token);
        string? token_type;
        response.get_string("token_type", out token_type);
        string? scope;
        response.get_string("scope", out scope);
        token = new Oauth2Token(access_token, refresh_token, token_type, scope);
        debug("Refreshed token: %s.", token.to_string());
        return true;
    }

    public async void start_device_code_grant(string device_code_endpoint) {
        if (token != null) {
            token = null;
        }
        Soup.Message msg = Soup.Form.request_new("POST", device_code_endpoint, "response_type", "tiliado_device_code",
            "client_id", client_id);
        if (client_secret != null) {
            msg.request_headers.replace("Authorization",
                "Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
        }

        HttpRequest request = create_request(msg);
        if (!yield request.send()) {
            string? error_description;
            string error_code = parse_error(request, out error_description);
            device_code_grant_error(error_code, error_description);
            return;
        }

        Drt.JsonObject? response = null;
        try {
            response = request.get_json_object();
        } catch (Drt.JsonError e) {
            device_code_grant_error("parse_error", Drt.error_to_string(e));
            return;
        }

        string device_code;
        if (!response.get_string("device_code", out device_code)) {
            device_code_grant_error("response_error", "The 'device_code' member is missing.");
            return;
        }
        string verification_uri;
        if (!response.get_string("verification_uri", out verification_uri)) {
            device_code_grant_error("response_error", "The 'verification_uri' member is missing.");
            return;
        }
        int interval;
        if (!response.get_int("interval", out interval)) {
            interval = 5;
        }

        this.device_code_endpoint = device_code_endpoint;
        this.device_code = device_code;
        this.device_code_cb_id = Timeout.add_seconds((uint) interval, device_code_grant_cb);
        device_code_grant_started(verification_uri);
    }

    public void cancel_device_code_grant() {
        this.device_code = null;
        this.device_code_endpoint = null;
        if (device_code_cb_id != 0) {
            Source.remove(device_code_cb_id);
            device_code_cb_id = 0;
        }
        device_code_grant_cancelled();
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

    protected override async bool authorize() {
        if (token == null) {
            return false;
        }
        try {
            return yield refresh_token();
        } catch (Oauth2Error e) {
            Drt.warn_error(e, "Failed to refresh access token.");
            return false;
        }
    }

    private bool device_code_grant_cb() {
        if (device_code_endpoint == null || device_code == null) {
            return false;
        }
        finish_device_code_grant.begin((o, res) => { finish_device_code_grant.end(res); });
        return true;
    }

    private async void finish_device_code_grant() {
        Soup.Message msg = Soup.Form.request_new("POST", device_code_endpoint, "grant_type", "tiliado_device_code",
            "client_id", client_id, "code", device_code);
        if (client_secret != null) {
            msg.request_headers.replace("Authorization",
                "Basic " + Base64.encode("%s:%s".printf(client_id, client_secret).data));
        }

        HttpRequest request = create_request(msg);
        yield request.send();
        Drt.JsonObject? response = null;
        if (device_code_endpoint == null || device_code == null) {
            return;
        }
        if (!request.is_ok()) {
            string error_description;
            string error_code = parse_error(request, out error_description);
            switch (error_code) {
            case "slow_down":
            case "authorization_pending":
                debug("Device code grant error: %s. %s", error_code, error_description);
                break;
            default:
                device_code_grant_error(error_code, error_description);
                cancel_device_code_grant();
                break;
            }
            return;
        }

        try {
            response = request.get_json_object();
        } catch (Drt.JsonError e) {
            device_code_grant_error("parse_error", "parse_error: " + Drt.error_to_string(e));
            cancel_device_code_grant();
            return;
        }

        string access_token;
        if (!response.get_string("access_token", out access_token)) {
            device_code_grant_error("response_error", "The 'access_token' member is missing.");
            cancel_device_code_grant();
            return;
        }

        string? refresh_token = response.get_string_or("refresh_token", null);
        string? token_type = response.get_string_or("token_type", null);
        string? scope = response.get_string_or("scope", null);
        token = new Oauth2Token(access_token, refresh_token, token_type, scope);
        debug("Device code grant token: %s.", token.to_string());
        device_code_cb_id = 0;
        this.device_code = null;
        this.device_code_endpoint = null;
        device_code_grant_finished(token);
    }

    private string parse_error(HttpRequest request, out string error_description) {
        Drt.JsonObject? response = null;
        try {
            response = request.get_json_object();
        } catch (Drt.JsonError e) {
            try {
                Drt.JsonArray array = request.get_json_array();
                string? err_str = null;
                if (array.length > 0 && array.get_string(0, out err_str) && err_str != null) {
                    error_description = "other_error: " + err_str;
                    return "other_error";
                }
            } catch (Drt.JsonError e) {
            }
            error_description = "parse_error: " + Drt.error_to_string(e);
            return "parse_error";
        }

        string error_code;
        if (!response.get_string("error", out error_code)) {
            error_code = "response_error";
            error_description = "The 'error' member is missing.";
        } else {
            error_description = response.get_string_or("description", null);
        }
        if (error_description == null) {
            error_description = error_code;
        } else {
            error_description = "%s: %s".printf(error_code, error_description);
        }
        return error_code;
    }

    protected override void add_headers(Soup.Message msg) {
        if (token != null && msg.request_headers.get_one("Authorization") == null) {
            msg.request_headers.replace("Authorization", "%s %s".printf(token.token_type, token.access_token));
        }
    }
}

public class Oauth2Token {
    public string access_token {get; private set;}
    public string? refresh_token {get; private set; default = null;}
    public string? token_type {get; private set; default = null;}
    public string? scope {get; private set; default = null;}

    public Oauth2Token(string access_token, string? refresh_token, string? token_type, string? scope) {
        this.access_token = access_token;
        this.refresh_token = refresh_token;
        this.token_type = token_type;
        this.scope = scope;
    }

    public string to_string() {
        return "access='%s'; refresh='%s';type='%s';scope='%s'".printf(access_token, refresh_token, token_type, scope);
    }
}

} // namespace Nuvola
