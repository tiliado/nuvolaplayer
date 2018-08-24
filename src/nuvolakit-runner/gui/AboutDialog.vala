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
        output.printf("%s script\n", web_app.name);
        output.printf("Version: %d.%d.%d\n", web_app.version_major, web_app.version_minor, web_app.version_micro);
        output.printf("Revision: %s\n", web_app.version_revision ?? "unknown");
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

public void debug_print_version_info(WebApp? web_app) {
    debug("%s %s (%s)", Nuvola.get_app_name(), Nuvola.get_version(), Nuvola.get_revision());
    if (web_app != null) {
        debug("%s script %d.%d.%d (%s)",
            web_app.name, web_app.version_major, web_app.version_minor, web_app.version_micro,
            web_app.version_revision ?? "unknown");
    }
    debug("Diorite %s", Drt.get_version());
    #if HAVE_CEF
    debug("Chromium %s", Cef.get_chromium_version());
    #endif
}

public class AboutDialog: Gtk.Dialog {
    public const string TAB_ABOUT = "about";
    public const string TAB_TIPS = "startup";
    public const string TAB_STARTUP = "startup";
    public const int RESPONSE_SHOW_NEWS = -9;
    public StartupView? startup {get; private set;}
    public Gtk.Stack stack {get; private set;}
    public Gtk.Grid grid {get; private set;}
    private Gtk.InfoBar? status = null;
    private unowned Gtk.Spinner? spinner;
    private unowned Gtk.Label? status_label;
    private unowned Gtk.Button? action_button;

    public AboutDialog(Gtk.Window? parent, Drt.Storage storage, StartupView? startup, WebApp? web_app, WebOptions[]? web_options, Gtk.Widget? sidebar) {
        GLib.Object(title: "About", transient_for: parent, use_header_bar: 1);
        set_default_size(300, -1);
        var grid = new Gtk.Grid();
        this.grid = grid;
        grid.orientation = Gtk.Orientation.HORIZONTAL;
        grid.margin = 15;
        grid.column_spacing = 10;
        Gtk.Container box = get_content_area();
        var stack = new Gtk.Stack();
        this.stack = stack;
        stack.hexpand = true;
        stack.transition_type  = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        Gtk.Widget screen = new AboutScreen(web_app, web_options);
        screen.show();
        stack.add_titled(screen, TAB_ABOUT, "About");
        if (web_app != null) {
            stack.add_titled(new TipsWidget(web_app, storage), TAB_TIPS, "Tips");
            stack.visible_child_name = TAB_TIPS;
        }
        if (startup != null) {
            stack.add_titled(startup, TAB_STARTUP, "Start-Up");
        }
        var switcher = new Gtk.StackSwitcher();
        switcher.stack = stack;
        switcher.hexpand = true;
        switcher.halign = Gtk.Align.CENTER;
        switcher.show();
        var header_bar = (Gtk.HeaderBar) get_header_bar();
        header_bar.custom_title = switcher;
        header_bar.show_close_button = true;
        box.add(grid);
        grid.attach(stack, 0, 1, 1, 1);
        if (sidebar != null) {
            grid.attach(sidebar, 1, 1, 1, 1);
            sidebar.set_size_request(150, -1);
        }
        box.show_all();
    }

    public void show_tab(string tab) {
        stack.visible_child_name = tab;
    }

    public void show_progress(Gtk.Label label) {
        set_status_label(label);
        status.message_type = Gtk.MessageType.INFO;

        if (this.spinner == null) {
            var spinner = new Gtk.Spinner();
            this.spinner = spinner;
            spinner.hexpand = true;
            spinner.valign = Gtk.Align.CENTER;
            spinner.halign = Gtk.Align.CENTER;
            spinner.margin = 10;
            status.add(spinner);
        }
        this.spinner.start();
        this.spinner.show();
    }

    public unowned Gtk.Button show_action(Gtk.Label label, string action, int response_id, Gtk.MessageType type) {
        if (spinner != null) {
            spinner.get_parent().remove(spinner);
            spinner = null;
        }
        if (action_button != null) {
            action_button.get_parent().remove(action_button);
            action_button = null;
        }
        set_status_label(label);
        status.message_type = type;

        return (action_button = status.add_button(action, response_id));
    }

    private void set_status_label(Gtk.Label label) {
        if (status == null) {
            status = new Gtk.InfoBar();
            status.hexpand = true;
            status.vexpand = false;
            status.valign = status.halign = Gtk.Align.CENTER;
            status.margin_bottom = 20;
            grid.attach(status, 0, 0, 2, 1);
            status.show();
            status.response.connect((id) => {this.response(id);});
        }
        if (status_label != null) {
            status_label.get_parent().remove(status_label);
        }
        status_label = label;
        label.margin_start = 20;
        label.margin_end = 20;
        status.get_content_area().add(label);
        label.show();
    }

    public bool show_welcome_note(Drt.KeyValueStorage config, bool force=false) {
        string? old_screen_name = config.get_string("nuvola.welcome_screen");
        if (force || old_screen_name != get_welcome_screen_name()) {
            string pattern = (old_screen_name == null ?
                "You have installed <b>%s %s %s</b>." : "You have upgraded to <b>%s %s %s</b>.");
            Gtk.Label label = Drtgtk.Labels.markup(pattern, get_app_name(), get_short_version(), "Runtime");
            label.yalign = 0.5f;
            show_tab(TAB_TIPS);
            show_action(label, "What's New", RESPONSE_SHOW_NEWS, Gtk.MessageType.INFO);
            config.set_string("nuvola.welcome_screen", get_welcome_screen_name());
            return true;
        }
        return false;
    }
}

} // namespace Nuvola
