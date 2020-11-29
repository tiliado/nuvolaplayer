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

public class AppearanceSettings: Gtk.Grid {
    private Config config;

    public AppearanceSettings(Config config) {
        this.config = config;
        margin = 20;
        hexpand = vexpand = true;
        halign = Gtk.Align.FILL;
        row_spacing = 25;
        column_spacing = 10;
        var theme_selector = new Drtgtk.GtkThemeSelector(true, config.get_string(ConfigKey.GTK_THEME) ?? "");
        theme_selector.hexpand = true;
        theme_selector.vexpand = false;
        theme_selector.halign = Gtk.Align.CENTER;
        theme_selector.valign = Gtk.Align.CENTER;
        theme_selector.changed.connect_after(on_theme_selector_changed);
        Gtk.Label label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "User interface theme", "This option has no effect on the theme of the web app itself.");
        label.halign = Gtk.Align.START;
        label.hexpand = true;
        int line = 0;
        attach(label, 0, ++line, 1, 1);
        attach(theme_selector, 1, line, 1, 1);
        #if FLATPAK
        label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "Get more themes",
            "Themes for Flatpak applications can be found on Flathub, the store for Flatpak apps."
            + " A restart is required after the installation of a new theme.");
        attach(label, 0, ++line, 1, 1);
        var link_button = new Gtk.LinkButton.with_label(
            "https://github.com/tiliado/nuvolaplayer/wiki/GTK-Themes", "Install themes");
        link_button.halign = Gtk.Align.CENTER;
        link_button.hexpand = true;
        attach(link_button, 1, line, 1, 1);
        #endif

        var dark_theme = new Gtk.Switch();
        label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "Prefer a dark variant if the theme provides it",
            "If no dark variant is available, this option has no effect.");
        dark_theme.active = config.get_bool(ConfigKey.DARK_THEME);
        dark_theme.notify["active"].connect_after(on_dark_theme_toggled);
        dark_theme.valign = dark_theme.halign = Gtk.Align.CENTER;
        attach(label, 0, ++line, 1, 1);
        attach(dark_theme, 1, line, 1, 1);

        var dark_scrollbar = new Gtk.Switch();
        label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "Use dark scrollbars for web view",
            "This option applies only on the web app itself.");
        dark_scrollbar.active = config.get_bool(ConfigKey.DARK_SCROLLBAR);
        dark_scrollbar.notify["active"].connect_after(on_dark_scrollbar_toggled);
        dark_scrollbar.valign = dark_scrollbar.halign = Gtk.Align.CENTER;
        attach(label, 0, ++line, 1, 1);
        attach(dark_scrollbar, 1, line, 1, 1);

        var system_decorations = new Gtk.Switch();
        label = Drtgtk.Labels.markup("<b>%s</b>\n<small>%s</small>",
            "Use system window decorations (requires restart)",
            "It may cause a visual inconsistency if the system theme differs from the application's theme.");
        system_decorations.active = config.get_bool(ConfigKey.SYSTEM_DECORATIONS);
        system_decorations.notify["active"].connect_after(on_system_decorations_toggled);
        system_decorations.valign = system_decorations.halign = Gtk.Align.CENTER;
        attach(label, 0, ++line, 1, 1);
        attach(system_decorations, 1, line, 1, 1);

        show_all();
    }

    private void on_dark_theme_toggled(GLib.Object toggle, ParamSpec param) {
        config.set_bool(ConfigKey.DARK_THEME, ((Gtk.Switch) toggle).active);
    }

    private void on_dark_scrollbar_toggled(GLib.Object toggle, ParamSpec param) {
        config.set_bool(ConfigKey.DARK_SCROLLBAR, ((Gtk.Switch) toggle).active);
    }

    private void on_system_decorations_toggled(GLib.Object toggle, ParamSpec param) {
        config.set_bool(ConfigKey.SYSTEM_DECORATIONS, ((Gtk.Switch) toggle).active);
    }

    private void on_theme_selector_changed(Gtk.ComboBox selector) {
        config.set_string(ConfigKey.GTK_THEME, selector.active_id);
    }
}

} // namespace Nuvola
