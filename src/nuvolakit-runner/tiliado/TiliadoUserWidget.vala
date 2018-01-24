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

namespace Nuvola {

public class TiliadoUserWidget : Gtk.Grid {
    public Component? component {get; private set; default = null;}
    private Gtk.Button? activate_button;
    private Gtk.Button? plan_button = null;
    private Gtk.Button? cancel_button = null;
    private Gtk.Button? logout_button = null;
    private Gtk.Button? refresh_button = null;
    private Gtk.Label? status_label = null;
    private Gtk.Grid button_box;
    private TiliadoActivation activation;
    private TiliadoApi2.User? current_user = null;
    private Drtgtk.Application app;

    public TiliadoUserWidget(TiliadoActivation activation, Drtgtk.Application app) {
        this.activation = activation;
        this.app = app;
        button_box = new Gtk.Grid();
        button_box.orientation = Gtk.Orientation.VERTICAL;
        button_box.halign = Gtk.Align.CENTER;
        button_box.hexpand = false;
        button_box.row_spacing = 10;
        margin = 5;
        margin_left = margin_right = 10;
        row_spacing = column_spacing = 5;

        activation.user_info_updated.connect(on_user_info_updated);
        activation.activation_started.connect(on_activation_started);
        activation.activation_failed.connect(on_activation_failed);
        activation.activation_cancelled.connect(on_activation_cancelled);
        activation.activation_finished.connect(on_activation_finished);
        current_user = activation.get_user_info();
    }

    public TiliadoUserWidget change_component(Component component) {
        this.component = component;
        check_user();
        return this;
    }

    ~TiliadoUserWidget() {
        activation.user_info_updated.disconnect(on_user_info_updated);
        activation.activation_started.disconnect(on_activation_started);
        activation.activation_failed.disconnect(on_activation_failed);
        activation.activation_cancelled.disconnect(on_activation_cancelled);
        activation.activation_finished.disconnect(on_activation_finished);
    }

    private void check_user() {
        if (component == null) {
            return;
        }
        var user = this.current_user;
        if (user == null) {
            get_token();
            return;
        }

        clear_all();

        logout_button = new Gtk.Button.with_label("Disconnect account");
        logout_button.clicked.connect(on_logout_button_clicked);
        refresh_button = new Gtk.Button.with_label("Refresh account details");
        refresh_button.clicked.connect(on_refresh_button_clicked);

        if (!component.is_membership_ok(activation)) {
            show_premium_required();
            plan_button = new Gtk.Button.with_label("Get %s".printf(component.required_membership.get_label()));
            plan_button.clicked.connect(on_plan_button_clicked);
            add_button(plan_button, "premium");
        }
        show_user_info();
        add_button(refresh_button);
        button_box.add(logout_button);
        attach(button_box, 0, 4, 2, 1);
        button_box.hexpand = true;
        button_box.vexpand = false;
        button_box.show_all();
    }

    private void show_premium_required() {
        var label = Drtgtk.Labels.markup(
            "This feature requires <b>%s</b>.", component.required_membership.get_label());
        label.margin = 10;
        label.halign = Gtk.Align.CENTER;
        label.hexpand = true;
        label.show();
        attach(label, 0, 0, 2, 1);
    }

    private void show_user_info() {
        if (current_user != null ) {
            var label = Drtgtk.Labels.markup("<b>User:</b> %s\n<b>Account:</b> %s",
                current_user.name, TiliadoMembership.from_uint(current_user.membership).get_label());
            label.halign = Gtk.Align.CENTER;
            label.hexpand = true;
            label.show();
            label.margin_bottom = 10;
            attach(label, 0, 1, 2, 1);
        }
    }

    private void get_token() {
        clear_all();
        show_premium_required();
        activate_button = new Gtk.Button.with_label("Connect Tiliado account");
        activate_button.clicked.connect(on_activate_button_clicked);
        add_button(activate_button, "suggested-action");
        plan_button = new Gtk.Button.with_label("Get %s".printf(component.required_membership.get_label()));
        plan_button.clicked.connect(on_plan_button_clicked);
        add_button(plan_button, "premium");
        attach(button_box, 0, 4, 2, 1);
        show_all();
    }

    private void clear_status_row() {
        if (cancel_button != null) {
            cancel_button.clicked.disconnect(on_cancel_button_clicked);
            remove(cancel_button);
            cancel_button = null;
        }
        if (status_label != null) {
            remove(status_label);
            status_label = null;
        }
    }

    private void clear_all() {
        clear_status_row();
        if (plan_button != null) {
            plan_button.clicked.disconnect(on_plan_button_clicked);
            button_box.remove(plan_button);
            plan_button = null;
        }
        if (activate_button != null) {
            activate_button.clicked.disconnect(on_activate_button_clicked);
            button_box.remove(activate_button);
            activate_button = null;
        }
        if (refresh_button != null) {
            refresh_button.clicked.disconnect(on_refresh_button_clicked);
            button_box.remove(refresh_button);
            refresh_button = null;
        }
        if (logout_button != null) {
            logout_button.clicked.disconnect(on_logout_button_clicked);
            button_box.remove(logout_button);
            logout_button = null;
        }
        foreach (var child in get_children()) {
            remove(child);
        }
    }

    private void add_button(Gtk.Button button, string? style_class=null) {
        button.hexpand = true;
        button.vexpand = false;
        button.halign = Gtk.Align.FILL;
        button.valign = Gtk.Align.CENTER;
        if (style_class != null) {
            button.get_style_context().add_class(style_class);
        }
        button.show();
        button_box.add(button);
    }

    private void on_activate_button_clicked(Gtk.Button button) {
        activate_button.sensitive = false;
        if (status_label != null) {
            remove(status_label);
        }

        status_label = new Gtk.Label("Authorization procedure in progress...");
        status_label.hexpand = true;
        status_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        status_label.set_line_wrap(true);
        status_label.show();
        attach(status_label, 0, 3, 1, 1);

        cancel_button = new Gtk.Button.with_label("Cancel");
        cancel_button.hexpand = true;
        cancel_button.vexpand = false;
        cancel_button.halign = Gtk.Align.END;
        cancel_button.valign = Gtk.Align.CENTER;
        cancel_button.clicked.connect(on_cancel_button_clicked);
        cancel_button.show();
        attach(cancel_button, 1, 3, 1, 1);

        activation.start_activation();
    }

    private void on_plan_button_clicked(Gtk.Button button) {
        app.show_uri("https://tiliado.eu/nuvolaplayer/funding/");
    }

    private void on_cancel_button_clicked(Gtk.Button button) {
        activation.cancel_activation();
    }

    private void on_logout_button_clicked(Gtk.Button button) {
        activation.drop_activation();
        get_token();
    }

    private void on_refresh_button_clicked(Gtk.Button button) {
        activation.update_user_info();
    }

    private void on_activation_started(string uri) {
        if (activate_button != null && !activate_button.sensitive) {
            app.show_uri(uri);
        }
    }

    private void on_activation_failed(string message) {
        activate_button.sensitive = true;
        clear_status_row();
        status_label = new Gtk.Label(null);
        status_label.set_markup(Markup.printf_escaped("<b>Authorization failed:</b> %s", message));
        status_label.hexpand = true;
        status_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        status_label.set_line_wrap(true);
        status_label.show();
        attach(status_label, 0, 3, 4, 1);
    }

    private void on_activation_cancelled() {
        activate_button.sensitive = true;
        clear_status_row();
    }

    private void on_activation_finished(TiliadoApi2.User? user) {
        this.current_user = user;
        check_user();
    }

    private void on_user_info_updated(TiliadoApi2.User? user) {
        this.current_user = user;
        check_user();
    }
}

} // namespace Nuvola
