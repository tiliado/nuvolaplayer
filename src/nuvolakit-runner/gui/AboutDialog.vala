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

public void print_version_info(FileStream output, WebApp? web_app) {
    if (web_app != null) {
        output.printf("%s script %d.%d\n", web_app.name, web_app.version_major, web_app.version_minor);
        output.printf("Maintainer: %s\n", web_app.maintainer_name);
        output.printf("\n--- Powered by ---\n\n");
    }
    #if GENUINE
    var blurb = "Genuine flatpak build";
    #else
    var blurb = "based on Nuvola Apps™ project";
    #endif
    output.printf("%s - %s\n", Nuvola.get_app_name(), blurb);
    output.printf("Version %s\n", Nuvola.get_version());
    output.printf("Revision %s\n", Nuvola.get_revision());
    output.printf("Diorite %s\n", Drt.get_version());
    output.printf("WebKitGTK %u.%u.%u\n", WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version());
    #if HAVE_CEF
    output.printf("Chromium %s\n", Cef.get_chromium_version());
    #else
    output.printf("Chromium N/A\n");
    #endif
    output.printf("libsoup %u.%u.%u\n", Soup.get_major_version(), Soup.get_minor_version(), Soup.get_micro_version());
}

public class AboutDialog: Gtk.Dialog {
    public AboutDialog(Gtk.Window? parent, WebApp? web_app, WebOptions[]? web_options) {
        GLib.Object(title: "About", transient_for: parent, use_header_bar: 1);
        resizable = false;
        add_button("_Close", Gtk.ResponseType.CLOSE);

        Gtk.Container box = get_content_area();
        var stack = new Gtk.Stack();
        stack.margin = 10;
        stack.hexpand = true;
        stack.transition_type  = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        Gtk.Widget screen = new AboutScreen(web_app);
        screen.show();
        stack.add_titled(screen, "About", "About");
        screen = new LibrariesScreen(web_options);
        screen.show();
        stack.add_titled(screen, "Libraries", "Libraries");
        var switcher = new Gtk.StackSwitcher();
        switcher.stack = stack;
        switcher.hexpand = true;
        switcher.halign = Gtk.Align.CENTER;
        switcher.show();
        ((Gtk.HeaderBar) get_header_bar()).custom_title = switcher;
        box.add(stack);
        box.show_all();
    }
}

} // namespace Nuvola
