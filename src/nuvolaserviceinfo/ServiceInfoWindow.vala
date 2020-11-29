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

public class Nuvola.ServiceInfoWindow : Gtk.Window {
    public ServiceInfoWindow() {
        string name = Nuvola.get_app_name();
        GLib.Object(title: "%s Service Info".printf(name));
        set_default_size(100, 100);
        check_nuvola_service_available.begin(null, (o, res) => {
            try {
                check_nuvola_service_available.end(res);
                show_info(null);
            } catch (GLib.Error e) {
                show_info(e.message);
            }
        });
    }

    private void show_info(string? error_message) {
        string name = Nuvola.get_app_name();
        string status = error_message != null
        ? "Unfortunately, the service failed to start: " + error_message
        : "You can close this window as the service starts automatically in background when needed.";

        Gtk.Label label = Drtgtk.Labels.markup((
            "<b>%s Service</b> is a background service that provides individual %s with global shared resources"
            + " such as <i>a global configuration storage</i>, <i>global keyboard shortcuts</i>,"
            + " <i>a HTTP remote control server</i>, and <i>a command-line controller</i>."
            + "\n\n%s"), name, name, status);
        label.halign = Gtk.Align.CENTER;
        label.hexpand = true;
        label.vexpand = false;
        label.justify = Gtk.Justification.CENTER;
        label.width_chars = 50;
        label.margin = 10;
        label.xalign = 0.5f;
        add(label);
        show_all();
    }

    private async void check_nuvola_service_available(Cancellable? cancellable = null) throws GLib.Error {
        DBusConnection bus = yield Bus.get(BusType.SESSION, cancellable);
        Drt.Dbus.Introspection nuvola = yield Drt.Dbus.introspect(bus, Nuvola.get_app_uid(), Nuvola.get_dbus_path());
        nuvola.assert_method("eu.tiliado.Nuvola", "GetConnection");
    }

    public static int main(string[] argv) {
        Gtk.init(ref argv);
        var window = new ServiceInfoWindow();
        window.delete_event.connect(() => {Gtk.main_quit(); return false;});
        Gtk.main();
        return 0;
    }
}
