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

public class GumroadLicense : GLib.Object {
    public bool valid {get; construct;}
    public bool success {get; construct;}
    // Not for subscriptions
    public bool refunded {get; construct;}
    // Not for subscriptions
    public bool chargebacked {get; construct;}
    public string? id {get; construct;}
    public string? product_id {get; construct;}
    public string? product_name {get; construct;}
    public string? license_key {get; construct;}
    public string? full_name {get; construct;}
    public string? email {get; construct;}
    public string? created_at {get; construct;}
    // Only for subscriptions
    public string? cancelled_at {get; construct;}
    // Only for subscriptions
    public string? failed_at {get; construct;}

    public GumroadLicense.from_json(Drt.JsonObject? json) {
        string? product_id = null;
        string? license_key = null;
        bool valid = false;
        bool success = false;
        bool refunded = false;
        bool chargebacked = false;
        string? id = null;
        string? product_name = null;
        string? full_name = null;
        string? email = null;
        string? created_at = null;
        string? cancelled_at = null;
        string? failed_at = null;
        if (json != null) {
            success = json.get_bool_or("success", false);
            license_key = json.get_string_or("x_license_key");
            product_id = json.get_string_or("x_product_id");
            Drt.JsonObject? purchase = json.get_object("purchase");
            if (purchase != null) {
                refunded = purchase.get_bool_or("refunded", false);
                chargebacked = purchase.get_bool_or("chargebacked", false);
                id = purchase.get_string_or("id");
                product_name = purchase.get_string_or("product_name");
                full_name = purchase.get_string_or("full_name");
                email = purchase.get_string_or("email");
                created_at = purchase.get_string_or("created_at");
                // it records cancellation date but not the remaining pre-paid period
                cancelled_at = purchase.get_string_or("subscription_cancelled_at");
                failed_at = purchase.get_string_or("subscription_failed_at");
                valid = success && !refunded && !chargebacked && cancelled_at == null && failed_at == null;
            }
        }
        GLib.Object(
            success: success, valid: valid, refunded: refunded, chargebacked: chargebacked,
            id: id, product_id: product_id, product_name: product_name, license_key: license_key,
            email: email, full_name: full_name,
            created_at: created_at, cancelled_at: cancelled_at, failed_at: failed_at
        );
    }

    public GumroadLicense.from_string(string json) throws Drt.JsonError {
        this.from_json(Drt.JsonParser.load_object(json));
    }

    public bool is_invalid_due_to_cancelled_subscription() {
        return success && !refunded && !chargebacked && (cancelled_at != null || failed_at != null);
    }

    public Drt.JsonBuilder to_json() {
        var builder = new Drt.JsonBuilder();
        builder.begin_object();
        builder.set_bool("success", success);
        builder.set_member("purchase");
        builder.begin_object();
        builder.set_bool("refunded", refunded);
        builder.set_bool("chargebacked", chargebacked);
        builder.set_string_or_null("id", id);
        builder.set_string_or_null("product_name", product_name);
        builder.set_string_or_null("full_name", full_name);
        builder.set_string_or_null("email", email);
        builder.set_string_or_null("created_at", created_at);
        builder.set_string_or_null("subscription_cancelled_at", cancelled_at);
        builder.set_string_or_null("subscription_failed_at", failed_at);
        builder.end_object();
        builder.set_string_or_null("x_product_id", product_id);
        builder.set_string_or_null("x_license_key", license_key);
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
