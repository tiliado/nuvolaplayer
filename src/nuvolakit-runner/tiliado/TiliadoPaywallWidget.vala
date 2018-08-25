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

public class TiliadoPaywallWidget : Gtk.Stack {
    private TiliadoPaywall paywall;
    private Phase phase = Phase.NONE;
    private View? main_view = null;
    private View? connecting_tiliado_account_view = null;
    private View? tiliado_account_error_view = null;
    private TiliadoAccountView? tiliado_account_view = null;
    private View? invalid_tiliado_account_view = null;
    private View? purchase_confirmation_needed = null;
    private bool activation_pending = false;

    public TiliadoPaywallWidget(TiliadoPaywall paywall) {
        this.paywall = paywall;
        paywall.tier_info_updated.connect(on_tier_info_updated);
        paywall.connecting_tiliado_account.connect(on_connecting_tiliado_account);
        paywall.tiliado_account_linking_cancelled.connect(on_tiliado_account_linking_cancelled);
        paywall.tiliado_account_linking_failed.connect(on_tiliado_account_linking_failed);
        paywall.tiliado_account_linking_finished.connect(on_tiliado_account_linking_finished);

        main_view = new View(null, {
            "Purchase Nuvola Runtime",
            "I purchased Nuvola Runtime",
            "Upgrade tier",
            "I have Tiliado Developer account",
            "Help",
            "Close"}, 0, {null});
        main_view.response.connect(on_main_view_response);
        reset();
    }

    ~TiliadoPaywallWidget() {
        paywall.tier_info_updated.disconnect(on_tier_info_updated);
        paywall.connecting_tiliado_account.disconnect(on_connecting_tiliado_account);
        paywall.tiliado_account_linking_cancelled.disconnect(on_tiliado_account_linking_cancelled);
        paywall.tiliado_account_linking_failed.disconnect(on_tiliado_account_linking_failed);
        paywall.tiliado_account_linking_finished.disconnect(on_tiliado_account_linking_finished);
    }

    public signal void close();

    public void reset() {
        phase = Phase.NONE;
        unowned View? view = main_view;
        TiliadoPaywall paywall = this.paywall;

        TiliadoApi2.User? user = paywall.get_tiliado_account();
        if (user != null && tiliado_account_view == null) {
            var account_view = new TiliadoAccountView(user, {"view-refresh-symbolic", "user-trash-symbolic"});
            account_view.buttons[1].get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            tiliado_account_view = account_view;
            account_view.response.connect(on_tiliado_account_view_response);
            view.attach(account_view, 0, 0, 1, 1);
        } else if (user == null && tiliado_account_view != null) {
            view.remove(tiliado_account_view);
            tiliado_account_view.response.disconnect(on_tiliado_account_view_response);
            tiliado_account_view = null;
        } else if (user != null && tiliado_account_view.user != user) {
            tiliado_account_view.update(user);
        }
        bool purchase = paywall.tier == TiliadoMembership.NONE;
        bool upgrade = !purchase && paywall.tier < TiliadoMembership.PREMIUM;
        view.buttons[MainAction.PURCHASE].visible = purchase;
        view.buttons[MainAction.PURCHASED].visible = purchase;
        view.buttons[MainAction.UPGRADE].visible = upgrade;
        view.buttons[MainAction.DEVELOPER].visible = purchase;
        view.buttons[MainAction.HELP].visible = true;
        view.buttons[MainAction.CLOSE].visible = true;
        switch_view(view);
    }

    private void on_main_view_response(int index, Gtk.Button button) {
        switch (index) {
        case MainAction.PURCHASE:
            paywall.open_purchase_page();
            break;
        case MainAction.PURCHASED:
            show_purchase_confirmation_needed();
            break;
        case MainAction.UPGRADE:
            paywall.open_upgrade_page();
            break;
        case MainAction.DEVELOPER:
            connect_tiliado_account(true);
            break;
        case MainAction.HELP:
            paywall.show_help_page();
            break;
        default:
            close();
            break;
        }
    }

    private void switch_view(View view) {
        if (view.get_parent() != null) {
            remove(view);
        }
        add(view);
        set_visible_child(view);
    }

    private void connect_tiliado_account(bool developer) {
        phase = developer ? Phase.DEVELOPER_ACCOUNT : Phase.TILIADO_ACCOUNT;
        paywall.connect_tiliado_account();
    }

    private void on_connecting_tiliado_account() {
        activation_pending = true;
        if (connecting_tiliado_account_view == null) {
            connecting_tiliado_account_view = new View(
                Drtgtk.Labels.markup(
                    "Follow instructions in a web browser to connect Nuvola Runtime with your Tiliado account."),
                {"Help", "Cancel"});
            connecting_tiliado_account_view.response.connect(on_connecting_tiliado_account_view_response);
        }
        switch_view(connecting_tiliado_account_view);
    }

    private void on_connecting_tiliado_account_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.show_help_page();
            break;
        default:
            paywall.cancel_tiliado_account_linking();
            break;
        }
    }

    private void on_tiliado_account_linking_cancelled() {
        reset();
        activation_pending = false;
    }

    private void on_tiliado_account_linking_failed(string message) {
        activation_pending = false;
        if (connecting_tiliado_account_view != null && visible_child == connecting_tiliado_account_view) {
            if (tiliado_account_error_view == null) {
                tiliado_account_error_view = new View(
                    Drtgtk.Labels.markup("Failed to ..."),
                    {"Try again", "Help", "Cancel"});
                tiliado_account_error_view.response.connect(on_tiliado_account_error_view_response);
            }
            tiliado_account_error_view.text_label.set_markup(Markup.printf_escaped(
                "<b>Failed to connect your Tiliado account:</b>\n\n%s", message));
            switch_view(tiliado_account_error_view);
        }
    }

    private void on_tiliado_account_error_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.connect_tiliado_account();
            break;
        case 1:
            paywall.show_help_page();
            break;
        default:
            paywall.cancel_tiliado_account_linking();
            break;
        }
    }

    private void on_tiliado_account_linking_finished() {
        activation_pending = false;
        switch (phase) {
        case Phase.DEVELOPER_ACCOUNT:
            check_developer_account();
            break;
        case Phase.TILIADO_ACCOUNT:
            check_tiliado_account();
            break;
        default:
            reset();
            break;
        }
    }

    private void check_developer_account() {
        TiliadoApi2.User? user = paywall.get_tiliado_account();
        if (user == null) {
            reset();
            return;
        }
        if (paywall.is_tiliado_developer()) {
            reset();
        } else {
            if (invalid_tiliado_account_view == null) {
                invalid_tiliado_account_view = new View(
                    Drtgtk.Labels.markup(""),
                    {"Refresh account info", "Help", "Cancel"}, 0);
                invalid_tiliado_account_view.response.connect(on_invalid_tiliado_account_view_response);
            }
            invalid_tiliado_account_view.text_label.set_markup(Markup.printf_escaped(
                "You don't have a Tiliado Developer account.\n\n<b>User:</b> %s\n<b>Tier:</b> %s",
                user.name, TiliadoMembership.from_uint(user.membership).get_label()));
            switch_view(invalid_tiliado_account_view);
        }
    }

    private void show_purchase_confirmation_needed() {
        if (purchase_confirmation_needed == null) {
            purchase_confirmation_needed = new View(
                Drtgtk.Labels.markup(
                    "<b>You should have received activation instructions from Tiliado. Please read them carefully.</b>\n\n"
                    + "Once a Nuvola developer confirms that your Gumroad and Tiliado accounts were linked, you "
                    + "can activate Nuvola with the button below."),
                {"I have received the confirmation", "I am still waiting for the confirmation", "Help"}, 0);
            purchase_confirmation_needed.response.connect(on_purchase_confirmation_needed_response);
        }
        switch_view(purchase_confirmation_needed);
    }

    private void on_purchase_confirmation_needed_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            connect_tiliado_account(false);
            break;
        case 2:
            paywall.show_help_page();
            break;
        default:
            reset();
            break;
        }
    }

    private void check_tiliado_account() {
        TiliadoApi2.User? user = paywall.get_tiliado_account();
        if (user == null) {
            reset();
            return;
        }
        if (paywall.has_tiliado_account_purchases()) {
            reset();
        } else {
            if (invalid_tiliado_account_view == null) {
                invalid_tiliado_account_view = new View(
                    Drtgtk.Labels.markup(""),
                    {"Refresh account info", "Help", "Cancel"}, 0);
                invalid_tiliado_account_view.response.connect(on_invalid_tiliado_account_view_response);
            }
            invalid_tiliado_account_view.text_label.set_markup(Markup.printf_escaped(
                "There is no purchase linked to your Tiliado account.\n\n<b>User:</b> %s\n<b>Tier:</b> %s",
                user.name, TiliadoMembership.from_uint(user.membership).get_label()));
            switch_view(invalid_tiliado_account_view);
        }
    }

    private void on_invalid_tiliado_account_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.connect_tiliado_account();
            break;
        case 1:
            paywall.show_help_page();
            break;
        default:
            reset();
            break;
        }
    }

    private void on_tiliado_account_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            connect_tiliado_account(false);
            break;
        case 1:
            paywall.disconnect_tiliado_account();
            break;
        default:
            close();
            break;
        }
    }

    // Event handlers
    private void on_tier_info_updated() {
        if (!activation_pending) {
            reset();
        }
    }

    private class View : Gtk.Grid {
        public Gtk.Button[] buttons;
        public Gtk.Label? text_label = null;
        public Gtk.Widget[]? extra_widgets = null;

        public View(Gtk.Label? text_label, string?[] buttons, int suggested_action=-1, owned Gtk.Widget?[]? extra_widgets=null) {
            hexpand = false;
            halign = Gtk.Align.FILL;
            margin = 20;
            column_spacing = row_spacing = 10;
            orientation = Gtk.Orientation.VERTICAL;
            int line = 0;
            if (text_label == null) {
                this.text_label = Drtgtk.Labels.markup("");
                text_label = this.text_label;
                text_label.hide();

            } else {
                text_label.show();
                this.text_label = text_label;
            }
            text_label.no_show_all = true;
            text_label.max_width_chars = 30;
            text_label.justify = Gtk.Justification.FILL;
            attach(text_label, 0, line++, 1, 1);

            if (extra_widgets != null) {
                foreach (unowned Gtk.Widget? widget in extra_widgets) {
                    line++;
                    if (widget != null) {
                        attach(widget, 0, line, 1, 1);
                    }
                }
                this.extra_widgets = (owned) extra_widgets;
            }

            this.buttons = new Gtk.Button[buttons.length];
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i] == null) {
                    continue;
                }
                var button = new Gtk.Button.with_label(buttons[i]);
                button.vexpand = false;
                button.hexpand = true;
                button.halign = Gtk.Align.FILL;
                button.no_show_all = true;
                button.show();
                if (i == suggested_action) {
                    button.get_style_context().add_class("suggested-action");
                }
                attach(button, 0, line + i, 1, 1);
                button.clicked.connect(on_button_clicked);
                this.buttons[i] = button;
                if (text_label != null && i == 0) {
                    button.vexpand = true;
                    button.valign = Gtk.Align.END;
                    button.margin_top = 20;
                }
            }
            show_all();
        }

        ~View() {
            foreach (unowned Gtk.Button button in buttons) {
                button.clicked.disconnect(on_button_clicked);
            }
        }

        public signal void response(int index, Gtk.Button button);

        private void on_button_clicked(Gtk.Button button) {
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i] == button) {
                    response(i, button);
                    return;
                }
            }
            response(-1, button);
        }
    }

    private class TiliadoAccountView : Gtk.Grid {
        public Gtk.Button?[]? buttons;
        public unowned TiliadoApi2.User? user = null;
        private unowned Gtk.Label? details = null;

        public TiliadoAccountView(TiliadoApi2.User user, owned string?[]? icon_buttons=null) {
            hexpand = false;
            halign = Gtk.Align.FILL;
            margin = 20;
            column_spacing = row_spacing = 10;
            orientation = Gtk.Orientation.VERTICAL;
            int line = 0;

            int n_icons = icon_buttons != null ? icon_buttons.length : 0;
            if (n_icons > 0) {
                this.buttons = new Gtk.Button[n_icons];
                for (var i = 0; i < n_icons; i++) {
                    if (icon_buttons[i] == null) {
                        continue;
                    }
                    var button = new Gtk.Button.from_icon_name(icon_buttons[i]);
                    button.vexpand = button.hexpand = false;
                    button.halign = button.valign = Gtk.Align.CENTER;
                    attach(button, i + 1, line, 1, 1);
                    button.clicked.connect(on_button_clicked);
                    this.buttons[i] = button;
                }
            }
            Gtk.Label header = Drtgtk.Labels.plain("<b>Tiliado Account</b>", false, true);
            header.yalign = 0.5f;
            attach(header, 0, line, 1, 1);
            var details = new Gtk.Label("");
            details.use_markup = true;
            details.set_line_wrap(true);
            details.max_width_chars = 30;
            this.details = details;
            update(user);
            attach(details, 0, ++line, n_icons + 1, 1);
            show_all();
        }

        ~TiliadoAccountView() {
            foreach (unowned Gtk.Button? button in buttons) {
                if (button != null) {
                    button.clicked.disconnect(on_button_clicked);
                }
            }
        }

        public void update(TiliadoApi2.User user) {
            TiliadoMembership tier = user.get_paywall_tier();
            unowned string? description = null;
            if (tier >= TiliadoMembership.DEVELOPER) {
                description = "Thank you for your work.";
            } else if (tier >= TiliadoMembership.BASIC) {
                description = "Thank you for purchasing Nuvola.";
            } else {
                description = "No active purchases found. Try refreshing data.";
            }
            details.label = Markup.printf_escaped(
                "<i>%s</i>\n\nUser: %s\nTier: %s", description, user.name, tier.get_label());
            this.user = user;
        }

        public signal void response(int index, Gtk.Button button);

        private void on_button_clicked(Gtk.Button button) {
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i] == button) {
                    response(i, button);
                    return;
                }
            }
            response(-1, button);
        }
    }

    private enum Phase {
        NONE,
        DEVELOPER_ACCOUNT,
        TILIADO_ACCOUNT;
    }

    private enum MainAction {
        PURCHASE,
        PURCHASED,
        UPGRADE,
        DEVELOPER,
        HELP,
        CLOSE;
    }
}

} // namespace Nuvola
