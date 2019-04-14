/*
 * Copyright 2016-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class PasswordManagerComponent: Component {
    #if EXPERIMENTAL
    private IpcBus ipc_bus;
    private WebWorker web_worker;
    private string web_app_id;
    private PasswordManager? manager = null;
    private PasswordManagerBinding? binding = null;
    private WebkitEngine engine;
    #endif

    public PasswordManagerComponent(Drt.KeyValueStorage config, IpcBus ipc_bus, WebWorker web_worker, string web_app_id, WebkitEngine engine) {
        base(
            config, "passwordmanager", "Password Manager (Experimental)",
            "Stores passwords from login forms in a keyring.", null);
        #if EXPERIMENTAL
        this.premium = true;
        this.ipc_bus = ipc_bus;
        this.web_worker = web_worker;
        this.web_app_id = web_app_id;
        this.engine = engine;
        #else
        available = false;
        #endif
    }

    #if EXPERIMENTAL
    protected override bool activate() {
        manager = new PasswordManager(engine, web_app_id);
        binding = new PasswordManagerBinding(ipc_bus.router, web_worker, manager);
        manager.fetch_passwords.begin(on_passwords_fetched);
        return true;
    }

    private void on_passwords_fetched(GLib.Object? o, AsyncResult res) {
        try {
            manager.fetch_passwords.end(res);
        } catch (GLib.Error e) {
            warning("Failed to fetch passwords. %s", e.message);
        }
        try {
            if (ipc_bus.web_worker != null) {
                ipc_bus.web_worker.call_sync("/nuvola/password-manager/enable", null);
            } else {
                ipc_bus.notify["web-worker"].connect_after(on_web_worker_notify);
            }
        } catch (GLib.Error e) {
            warning("Failed to enable the password manager: %s", e.message);
        }
    }

    protected override bool deactivate() {
        try {
            if (ipc_bus.web_worker != null) {
                web_worker.call_sync("/nuvola/password-manager/disable", null);
            } else {
                ipc_bus.notify["web-worker"].connect_after(on_web_worker_notify);
            }
        } catch (GLib.Error e) {
            warning("Failed to disable the password manager: %s", e.message);
        }
        binding.dispose();
        binding = null;
        manager = null;
        return true;
    }

    private void on_web_worker_notify(GLib.Object o, ParamSpec p) {
        var bus = o as IpcBus;
        if (bus != null && bus.web_worker != null) {
            try {
                web_worker.call_sync("/nuvola/password-manager/" + (enabled ? "enable": "disable"), null);
                ipc_bus.notify["web-worker"].disconnect(on_web_worker_notify);
            } catch (GLib.Error e) {
                warning("Failed to %s the password manager. %s", enabled ? "enable": "disable", e.message);
            }
        }
    }
    #endif
}

} // namespace Nuvola
