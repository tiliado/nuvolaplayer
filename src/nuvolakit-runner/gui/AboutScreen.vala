/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class AboutScreen: Gtk.Grid {
    public AboutScreen(WebApp? web_app, WebOptions[]? web_options) {
        Pango.AttrList attributes = null;
        Gtk.Label label;
        Gtk.Image? img = null;
        var icon_size = 64;
        int line = 0;
        column_spacing = 5;
        halign = Gtk.Align.CENTER;
        hexpand = true;

        if (web_app != null) {
            Gdk.Pixbuf? pixbuf = web_app.get_icon_pixbuf(icon_size);
            if (pixbuf != null) {
                img = new Gtk.Image.from_pixbuf(pixbuf);
                img.valign = img.halign = Gtk.Align.CENTER;
                attach(img, 0, line, 1, 3);
            }

            label = new Gtk.Label(web_app.name + " script");
            attributes = new Pango.AttrList() ;
            attributes.insert(new Pango.AttrFontDesc(Pango.FontDescription.from_string("bold")));
            label.attributes = (owned) attributes;
            attach(label, 1, line, 2, 1);
            line++;
            attach(new Gtk.Label("Version"), 1, line, 1, 1);
            label = new Gtk.Label("%u.%u.%u (%s)".printf(
                web_app.version_major, web_app.version_minor, web_app.version_micro,
                web_app.version_revision ?? "unknown revision"));
            label.selectable = true;
            attach(label, 2, line, 1, 1);
            line++;
            attach(new Gtk.Label("Maintainer"), 1, line, 1, 1);
            label = new Gtk.Label(web_app.maintainer_name);
            label.use_markup = true;
            attach(label, 2, line, 1, 1);

            string app_name = Markup.printf_escaped("<i>%s</i>", web_app.name);
            label = new Gtk.Label((
                "<small>This script is not affiliated with nor endorsed by the {name} website and its operators/owners."
                + " {name} may be a trademark or a registered trademark owned by the operators/owners of the {name}"
                + " website.</small>").replace("{name}", app_name));
            label.margin = 20;
            label.use_markup = true;
            label.set_line_wrap(true);
            label.max_width_chars = 50;
            label.show();
            line++;
            attach(label, 0, line, 3, 1);
            line++;
        }

        Gdk.Pixbuf? pixbuf = Drtgtk.Icons.load_theme_icon({Nuvola.get_app_icon()}, icon_size);
        if (pixbuf != null) {
            img = new Gtk.Image.from_pixbuf(pixbuf);
            img.valign = img.halign = Gtk.Align.CENTER;
            attach(img, 0, line, 1, 3);
        }

        string name = Nuvola.get_app_name();
        label = new Gtk.Label(name + " Runtime");
        attributes = new Pango.AttrList() ;
        attributes.insert(new Pango.AttrFontDesc(Pango.FontDescription.from_string("bold")));
        label.attributes = (owned) attributes;
        attach(label, 1, line, 2, 1);
        line++;
        attach(new Gtk.Label("Version"), 1, line, 1, 1);
        string revision = Nuvola.get_revision();
        label = new Gtk.Label("%s (%s)".printf(Nuvola.get_version(), revision));
        label.selectable = true;
        attach(label, 2, line, 1, 1);
        line++;
        attach(new Gtk.Label("Copyright"), 1, line, 1, 1);
        label = new Gtk.Label(Markup.printf_escaped("© 2011-2018 %s", "Jiří Janoušek"));
        label.use_markup = true;
        attach(label, 2, line, 1, 1);

        #if !GENUINE
        label = new Gtk.Label(
            "<small>This third-party build is not affiliated with, endorsed by nor supported by the Nuvola Apps Project.</small>");
        label.use_markup = true;
        label.margin = 20;
        label.margin_bottom = 10;
        label.set_line_wrap(true);
        label.max_width_chars = 50;
        label.show();
        line++;
        attach(label, 0, line, 3, 1);
        var button = new Gtk.LinkButton.with_label("https://nuvola.tiliado.eu", "Get genuine Nuvola Apps Runtime");
        line++;
        attach(button, 0, line, 3, 1);
        #endif

        label = Drtgtk.Labels.markup("<b>Libraries</b>");
        label.margin_top = 20;
        label.halign = Gtk.Align.CENTER;
        attach(label, 0, ++line, 3, 1);
        label = new Gtk.Label("Diorite: %s".printf(Drt.get_version()));
        label.selectable = true;
        attach(label, 0, ++line, 3, 1);
        if (web_options != null) {
            foreach (WebOptions entry in web_options) {
                label = new Gtk.Label("Web Engine: " + entry.get_name_version());
                label.selectable = true;
                attach(label, 0, ++line, 3, 1);
            }
        }
        label = new Gtk.Label("Network Library: libsoup %u.%u.%u".printf(
            Soup.get_major_version(), Soup.get_minor_version(), Soup.get_micro_version()));
        label.selectable = true;
        attach(label, 0, ++line, 3, 1);

        show_all();
        hide();
    }
}

} // namespace Nuvola
