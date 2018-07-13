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

public class AppearanceSettings: Gtk.Grid {
    private Config config;

    public AppearanceSettings(Config config) {
        this.config = config;
        margin = 20;
        hexpand = vexpand = true;
        halign = Gtk.Align.FILL;
        row_spacing = 20;
        var theme_selector = new Drtgtk.GtkThemeSelector(true, config.get_string(ConfigKey.GTK_THEME) ?? "");
        theme_selector.hexpand = true;
        theme_selector.halign = Gtk.Align.START;
        theme_selector.changed.connect_after(on_theme_selector_changed);
        var label = new Gtk.Label("User interface theme");
        label.halign = Gtk.Align.START;
        label.hexpand = true;
        int line = 0;
        attach(label, 0, ++line, 1, 1);
        attach(theme_selector, 1, line, 1, 1);
        #if FLATPAK
        var link_button = new Gtk.LinkButton.with_label(
            "https://github.com/tiliado/nuvolaruntime/wiki/GTK-Themes", "Install themes");
        link_button.halign = Gtk.Align.START;
        link_button.hexpand = true;
        attach(link_button, 2, line, 1, 1);
        #endif

        var dark_theme = new Gtk.Switch();
        label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "Prefer a dark variant if the theme provides it.",
            "If no dark variant is available, this option has no effect.");
        dark_theme.active = config.get_bool(ConfigKey.DARK_THEME);
        dark_theme.notify["active"].connect_after(on_dark_theme_toggled);
        dark_theme.valign = dark_theme.halign = Gtk.Align.CENTER;
        attach(label, 0, ++line, 2, 1);
        attach(dark_theme, 2, line, 1, 1);

        show_all();
    }

    private void on_dark_theme_toggled(GLib.Object toggle, ParamSpec param) {
        config.set_bool(ConfigKey.DARK_THEME, ((Gtk.Switch) toggle).active);
    }
    }

    private void on_theme_selector_changed(Gtk.ComboBox selector) {
        config.set_string(ConfigKey.GTK_THEME, selector.active_id);
    }
}

} // namespace Nuvola
