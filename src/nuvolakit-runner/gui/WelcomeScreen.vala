/*
 * Copyright 2015-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WelcomeScreen : Gtk.Grid {
    private Gtk.Grid grid;
    private Drtgtk.Application app;
    private Drtgtk.RichTextView welcome_text;
    private Gtk.ScrolledWindow scroll;

    public WelcomeScreen(Drtgtk.Application app, Drt.Storage storage) {
        this.app = app;

        grid = new Gtk.Grid();
        grid.orientation = Gtk.Orientation.VERTICAL;

        string welcome_xml = null;
        File welcome_xml_file = storage.require_data_file("welcome.xml");
        try {
            welcome_xml = Drt.System.read_file(welcome_xml_file);
        } catch (GLib.Error e) {
            error("Failed to load '%s': %s", welcome_xml_file.get_path(), e.message);
        }

        var buffer = new Drtgtk.RichTextBuffer();
        try {
            buffer.load(welcome_xml);
        } catch (MarkupError e) {
            error("Markup Error in '%s': %s", welcome_xml_file.get_path(), e.message);
        }

        welcome_text = new Drtgtk.RichTextView(buffer);
        welcome_text.set_link_opener(show_uri);
        welcome_text.margin = 18;
        welcome_text.vexpand = welcome_text.hexpand = true;
        welcome_text.halign = Gtk.Align.FILL;
        grid.attach(welcome_text, 0, 0, 1, 1);

        var patrons = new PatronBox();
        grid.attach(patrons, 1, 0, 1, 1);

        scroll = new Gtk.ScrolledWindow(null, null);
        scroll.add(grid);
        scroll.vexpand = true;
        scroll.hexpand = true;
        add(scroll);
        scroll.show_all();
    }



    private void show_uri(string uri) {
        app.show_uri(uri);
    }
}

} // namespace Nuvola
