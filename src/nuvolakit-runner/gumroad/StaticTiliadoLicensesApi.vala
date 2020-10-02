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

public class StaticTiliadoLicensesApi : HttpClient {
    private static bool debug_soup;

    static construct {
        debug_soup = Environment.get_variable("GUMROAD_DEBUG_SOUP") == "yes";
    }

    public StaticTiliadoLicensesApi(string? api_endpoint) {
        base(api_endpoint ?? "https://gk.tiliado.eu/", debug_soup);
    }

    public async GumroadLicense? get_license(string product_id, string license_key, bool increment_uses_count)
    throws GumroadError {
        Drt.JsonObject? response = null;
        HttpRequest request = call("%s/%s".printf(product_id, license_key));
        if (yield request.send()) {
            try {
                response = request.get_json_object();
            } catch (Drt.JsonError e) {
                throw new GumroadError.LICENSE_ERROR(Drt.error_to_string(e));
            }
        } else if (request.is_not_found()) {
            return null;
        } else {
            throw new GumroadError.LICENSE_ERROR(request.get_reason());
        }
        response["x_product_id"] = new Drt.JsonValue.@string(product_id);
        response["x_license_key"] = new Drt.JsonValue.@string(license_key);
        return new GumroadLicense.from_json(response);
    }
}

} // namespace Nuvola
