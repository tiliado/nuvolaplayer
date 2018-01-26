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

using WebKit.DOM;

namespace Nuvola {

public class LoginFormManager: GLib.Object {
    private HashTable<string, Drt.Lst<LoginCredentials>> credentials = null;
    private Drt.Lst<LoginForm> login_forms;
    private WebKit.WebPage page = null;
    private uint look_up_forms_source_id = 0;
    private uint look_up_forms_attempts = 0;
    private Drt.RpcChannel channel;
    private unowned LoginForm context_menu_form = null;

    public LoginFormManager(Drt.RpcChannel channel) {
        credentials = new HashTable<string, Drt.Lst<LoginCredentials>>(str_hash, str_equal);
        login_forms = new Drt.Lst<LoginForm>();
        this.channel = channel;
        request_passwords();
        channel.router.add_method("/nuvola/passwordmanager/prefill-username", Drt.RpcFlags.WRITABLE,
            "Prefill username.",
            handle_prefill_username, {
                new Drt.IntParam("index", true, null, "Username index.")
            });
    }

    ~LoginFormManager() {
        debug("~LoginFormManager");
        channel.router.remove_method("/nuvola/passwordmanager/prefill-username");
    }

    private void request_passwords() {
        channel.call.begin("/nuvola/passwordmanager/get-passwords", null, (o, res) => {
            try {
                var passwords = channel.call.end(res);
                if (passwords != null) {
                    return_if_fail(passwords.is_of_type(new VariantType("a(sss)")));
                    var iter = passwords.iterator();
                    string hostname = null;
                    string username = null;
                    string password = null;
                    while (iter.next("(sss)", out hostname, out username, out password)) {
                        add_credentials(hostname, username, password);
                    }
                }
            } catch (GLib.Error e) {
                critical("Failed to get passwords. %s", e.message);
            }
        });
    }

    public void store_credentials(string hostname, string username, string password) {
        add_credentials(hostname, username, password);
        store_password.begin(hostname, username, password, (o, res) => { store_password.end(res); });
    }

    private void add_credentials(string hostname, string username, string password) {
        var entries = credentials[hostname];
        if (entries == null) {
            entries = new Drt.Lst<LoginCredentials>(LoginCredentials.username_equals);
            entries.prepend(new LoginCredentials(username, password));
            credentials[hostname] = entries;
        }
        else {
            var entry = new LoginCredentials(username, password);
            var index = entries.index(entry);
            if (index >= 0)
            entries[index] = entry;
            else
            entries.prepend(entry);
        }
    }

    private async void store_password(string hostname, string username, string password) {
        debug("Store password for '%s' at '%s'".printf(username, hostname));
        try {
            yield channel.call("/nuvola/passwordmanager/store-password", new Variant("(sss)", hostname, username, password));
        }
        catch (GLib.Error e) {
            warning("Failed to store password for '%s' at '%s'. %s".printf(username, hostname, e.message));
        }
    }

    public void remove_credentials(string? hostname, string? username) {
        if (hostname == null) {
            credentials.remove_all();
        }
        else if (username == null) {
            credentials.remove(hostname);
        }
        else {
            var entries = credentials[hostname];
            if (entries != null)
            entries.remove(new LoginCredentials(username, null));
        }
    }

    private SList<LoginCredentials>? get_credentials(string hostname, string? username) {
        var entries = credentials[hostname];
        if (entries != null) {
            if (username == null)
            return entries.to_slist();
            SList<LoginCredentials> result = null;
            foreach (var entry in entries) {
                if (entry.username == username)
                result.prepend(entry);
            }
            result.reverse();
            return result;
        }
        return null;
    }

    public void add(LoginForm form) {
        form.subscribe();
        prefill(form, true);
        form.new_credentials.connect(on_new_credentials_from_form);
        form.username_changed.connect(on_form_username_changed);
        login_forms.prepend(form);
    }

    public void clear_forms() {
        foreach (var form in login_forms) {
            form.new_credentials.disconnect(on_new_credentials_from_form);
            form.username_changed.disconnect(on_form_username_changed);
            form.unsubscribe();
        }
        login_forms = new Drt.Lst<LoginForm>();
    }

    public bool prefill(LoginForm form, bool force=false) {
        var username = form.username != null ? form.username.value : "";
        var entries = get_credentials(form.uri.host, username);
        if (entries != null) {
            form.fill(entries.data.username, entries.data.password, force);
            return true;
        }
        return false;
    }

    public void manage_forms(WebKit.WebPage page) {
        this.page = page;
        if (look_up_forms_source_id != 0) {
            Source.remove(look_up_forms_source_id);
            look_up_forms_source_id = 0;
        }
        clear_forms();
        look_up_forms_attempts = 0;
        if (!look_up_forms())
        look_up_forms_source_id = Timeout.add_seconds(2, look_up_forms_cb);
    }

    public bool manage_context_menu(WebKit.ContextMenu menu, WebKit.DOM.Node? node) {
        if (node != null && node is HTMLInputElement) {
            foreach (var form in login_forms) {
                if (form.username == node || form.password == node) {
                    context_menu_form = form;
                    var entries = get_credentials(form.uri.host, null);
                    if (entries != null) {
                        var builder = new VariantBuilder(new VariantType("as"));
                        foreach (var entry in entries)
                        builder.add_value(entry.username);
                        menu.set_user_data(new Variant("(sas)", "prefill-password", builder));
                        return true;
                    }
                    break;
                }
            }
        }
        return false;
    }

    private bool look_up_forms() {
        var document = page.get_dom_document();
        var forms = document.forms;
        var n_forms = forms.length;
        if (n_forms == 0)
        return false;

        var form_found = false;
        for (var i = 0; i < n_forms; i++) {
            var form = forms.item(i) as HTMLFormElement;
            assert(form != null);
            HTMLInputElement? username;
            HTMLInputElement? password;
            HTMLElement? submit;
            if (find_login_form_entries(form, out username, out password, out submit)) {
                var login_form = new LoginForm(page, form, username, password, submit);
                add(login_form);
                form_found = true;
            }
        }
        return form_found;
    }

    private bool look_up_forms_cb() {
        return !(look_up_forms() || ++look_up_forms_attempts >= 30);
    }

    private void on_new_credentials_from_form(LoginForm form, string hostname, string username, string password) {
        store_credentials(hostname, username, password);
        Idle.add(() => {prefill(form); return false;});
    }

    private void on_form_username_changed(LoginForm form, string hostname, string? username) {
        debug("Username changed %s %s", hostname, username);
        prefill(form);
    }

    private void handle_prefill_username(Drt.RpcRequest request) throws Drt.RpcError {
        if (context_menu_form != null) {
            var index = request.pop_int();
            var entries = get_credentials(context_menu_form.uri.host, null);
            if (entries != null) {
                unowned LoginCredentials credentials = entries.nth_data((uint) index);
                if (credentials != null)
                context_menu_form.fill(credentials.username, credentials.password, true);
            }
            context_menu_form = null;
        }
        request.respond(null);
    }

    public static bool find_login_form_entries(WebKit.DOM.HTMLFormElement form,
        out WebKit.DOM.HTMLInputElement? username, out WebKit.DOM.HTMLInputElement password,
        out WebKit.DOM.HTMLElement? submit) {
        username = null;
        password = null;
        submit = null;
        var inputs = form.elements;
        var n_inputs = inputs.length;
        WebKit.DOM.HTMLInputElement? username_node = null;
        WebKit.DOM.HTMLInputElement? password_node = null;
        WebKit.DOM.HTMLElement? submit_node = null;
        for (var i = 0; i < n_inputs; i++) {
            var input = inputs.item(i) as WebKit.DOM.HTMLInputElement;
            if (input == null) {
                var button = inputs.item(i) as WebKit.DOM.HTMLButtonElement;
                if (button.type == "submit")
                submit_node = button;
                continue;
            }
            var input_type = input.type;
            if (input_type == "text" || input_type == "tel" || input_type == "email") {
                if (username_node != null)
                return false;
                username_node = input;
            }
            else if (input_type == "password") {
                if (password_node != null)
                return false;
                password_node = input;
            }
            else if (input_type == "submit") {
                submit_node = input;
            }
        }

        if (password_node != null) {
            username = username_node;
            password = password_node;
            submit = submit_node;
            return true;
        }
        return false;
    }
}

} // namespace Nuvola
