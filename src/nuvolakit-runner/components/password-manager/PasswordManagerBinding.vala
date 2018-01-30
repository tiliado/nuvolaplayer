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

public class PasswordManagerBinding : ModelBinding<PasswordManager> {
    public PasswordManagerBinding(Drt.RpcRouter router, WebWorker web_worker, PasswordManager model) {
        base(router, web_worker, "Nuvola.PasswordManager", model);
        model.prefill_username.connect(on_prefil_username);
    }

    ~PasswordManagerBinding() {
        debug("~PasswordManagerBinding");
        model.prefill_username.disconnect(on_prefil_username);
    }

    protected override void bind_methods() {
        bind("get-passwords", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Returns passwords.", handle_get_passwords, null);
        bind("store-password", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE, null, handle_store_password, {
            new Drt.StringParam("hostname", true, false),
            new Drt.StringParam("username", true, false),
            new Drt.StringParam("password", true, false),
        });
    }

    private void handle_store_password(Drt.RpcRequest request) throws Drt.RpcError {
        string? hostname = request.pop_string();
        string? username = request.pop_string();
        string? password = request.pop_string();
        model.store_password.begin(hostname, username, password, null, (o, res) => {model.store_password.end(res);});
        request.respond(null);
    }

    private void handle_get_passwords(Drt.RpcRequest request) throws Drt.RpcError {
        var builder = new VariantBuilder(new VariantType("a(sss)"));
        HashTable<string, Drt.Lst<LoginCredentials>> passwords = model.get_passwords();
        if (passwords != null) {
            HashTableIter<string, Drt.Lst<LoginCredentials>> iter = HashTableIter<string, Drt.Lst<LoginCredentials>>(passwords);
            string hostname = null;
            Drt.Lst<LoginCredentials> credentials = null;
            while (iter.next(out hostname, out credentials)) {
                foreach (LoginCredentials item in credentials) {
                    builder.add("(sss)", hostname, item.username, item.password);
                }
            }
        }
        request.respond(builder.end());
    }

    private void on_prefil_username(int index) {
        try {
            web_worker.call_sync("/nuvola/passwordmanager/prefill-username", new Variant("(i)", index));
        }
        catch (GLib.Error e) {
            warning("Request to prefill username %d failed. %s", index, e.message);
        }
    }
}

} // namespace Nuvola
