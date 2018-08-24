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

public class MasterUserInterface: GLib.Object {
    public const string START_APP = "start-app";
    public const string QUIT = "quit";

    public MasterWindow? main_window {get; private set; default = null;}
    public WebAppList? web_app_list {get; private set; default = null;}
    private unowned MasterController controller;
    private TiliadoUserAccountWidget? tiliado_widget = null;
    private TiliadoTrialWidget? tiliado_trial = null;
    private WebAppStorage app_storage;
    private Drt.Storage storage;

    public MasterUserInterface(MasterController controller) {
        this.controller = controller;
        #if FLATPAK
        Graphics.ensure_gl_extension_mounted(main_window);
        #endif

        Drtgtk.Action[] actions_spec = {
            //          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
            new Drtgtk.SimpleAction("main", "app", Actions.HELP, "Help", "_Help", null, "F1", do_help),
            new Drtgtk.SimpleAction("main", "app", Actions.ABOUT, "About", "_About", null, null, do_about),
            new Drtgtk.SimpleAction("main", "app", QUIT, "Quit", "_Quit", "application-exit", "<ctrl>Q", do_quit),
            new Drtgtk.SimpleAction("main", "win", START_APP, "Start app", "_Start app", "media-playback-start", "<ctrl>S", do_start_app),
        };
        controller.actions.add_actions(actions_spec);
        controller.set_app_menu_items({Actions.HELP, Actions.ABOUT, QUIT});
    }

    private void create_main_window() {
        storage = controller.storage;
        app_storage = new WebAppStorage(storage.user_config_dir, storage.user_data_dir, storage.user_cache_dir);
        main_window = new MasterWindow(controller);
        main_window.page_changed.connect(on_master_stack_page_changed);

        if (controller.web_app_reg != null) {
            var model = new WebAppListFilter(new WebAppListModel(controller.web_app_reg), controller.debuging, null);
            web_app_list = new WebAppList(controller, model);
            main_window.delete_event.connect(on_main_window_delete_event);
            web_app_list.view.item_activated.connect_after(on_list_item_activated);
            web_app_list.show();
            main_window.add_page(web_app_list, "scripts", "Installed Apps");
        }

        if (controller.activation != null) {
            tiliado_trial = new TiliadoTrialWidget(controller.activation, controller, TiliadoMembership.BASIC);
            main_window.top_grid.attach(tiliado_trial, 0, 4, 1, 1);
            tiliado_widget = new TiliadoUserAccountWidget(controller.activation);
            main_window.header_bar.pack_end(tiliado_widget);
        }

        #if FLATPAK
        is_desktop_portal_available.begin((o, res) => is_desktop_portal_available.end(res));
        #endif
    }

    public void show_main_window(string? page=null) {
        if (main_window == null) {
            create_main_window();
        }
        main_window.present();
        if (page != null) {
            main_window.stack.visible_child_name = page;
        }
    }

    #if FLATPAK
    public async bool is_desktop_portal_available() {
        try {
            yield Drt.Flatpak.check_desktop_portal_available(null);
            return true;
        } catch (GLib.Error e) {
            var dialog = new Gtk.MessageDialog.with_markup(
                main_window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                ("<b><big>Failed to connect to XDG Desktop Portal</big></b>\n\n"
                    + "Make sure the XDG Desktop Portal is installed on your system. "
                    + "It might be sufficient to install the xdg-desktop-portal and xdg-desktop-portal-gtk "
                    + "packages. If unsure, follow detailed installation instructions at https://nuvola.tiliado.eu"
                    + "\n\n%s"), e.message);
            Timeout.add_seconds(120, () => { dialog.destroy(); return false;});
            dialog.run();
            return false;
        }
    }
    #endif

    private void set_toolbar(string[] items) {
        main_window.create_toolbar(items);
        if (tiliado_widget != null) {
            main_window.header_bar.pack_end(tiliado_widget);
        }
    }

    private bool on_main_window_delete_event(Gdk.EventAny event) {
        do_quit();
        return true;
    }

    private void do_quit() {
        main_window.hide();
        controller.remove_window(main_window);
        main_window.destroy();
        main_window = null;
    }

    private void on_list_item_activated(Gtk.TreePath path) {
        do_start_app();
    }

    private void do_about() {
        var dialog = new AboutDialog(main_window, storage, null, null, {
            #if HAVE_CEF
            new CefOptions(app_storage, null),
            #endif
            new WebkitOptions(app_storage, null),
        }, new PatronBox());
        dialog.run();
        dialog.destroy();
    }

    private void do_help() {
        controller.show_uri(Nuvola.HELP_URL);
    }

    private void do_start_app() {
        if (web_app_list.selected_web_app == null) {
            return;
        }
        main_window.hide();
        controller.start_app.begin(web_app_list.selected_web_app, (o, res) => controller.start_app.end(res));
    }

    private void on_master_stack_page_changed(Gtk.Widget? page, string? name, string? title) {
        if (page != null && page == web_app_list) {
            set_toolbar({START_APP});
            // For Unity
            controller.reset_menubar().append_submenu("_Apps", controller.actions.build_menu({START_APP}));
        } else {
            set_toolbar({});
            controller.reset_menubar();
        }
    }
}

} // namespace Nuvola
