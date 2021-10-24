/*
 * Copyright 2018-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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
    private View? license_key_view = null;
    private View? verifying_gumroad_license_view = null;
    private GumroadLicenseView? gumroad_license_view = null;
    private View? license_failure_view = null;
    private View? license_invalid_view = null;
    private bool activation_pending = false;

    public TiliadoPaywallWidget(TiliadoPaywall paywall) {
        this.paywall = paywall;
        paywall.tier_info_updated.connect(on_tier_info_updated);
        paywall.gumroad_license_verification_failed.connect(on_gumroad_license_verification_failed);
        paywall.gumroad_license_invalid.connect(on_gumroad_license_invalid);

        main_view = new View(null, {
            "Purchase Nuvola Player",
            "I purchased Nuvola Player",
            "Upgrade tier",
            "I have Developer key",
            "Help",
            "Close"}, 0, {null, null, null});
        main_view.response.connect(on_main_view_response);
        reset();
    }

    ~TiliadoPaywallWidget() {
        paywall.tier_info_updated.disconnect(on_tier_info_updated);
        paywall.gumroad_license_verification_failed.disconnect(on_gumroad_license_verification_failed);
        paywall.gumroad_license_invalid.disconnect(on_gumroad_license_invalid);
    }

    public signal void close();

    public void reset() {
        phase = Phase.NONE;
        unowned View? view = main_view;
        TiliadoPaywall paywall = this.paywall;

        TiliadoLicense? license = paywall.get_gumroad_license();
        if (license != null && gumroad_license_view == null) {
            var license_view = new GumroadLicenseView(license, {"document-edit-symbolic", "user-trash-symbolic"});
            license_view.buttons[1].get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            gumroad_license_view = license_view;
            license_view.response.connect(on_gumroad_license_view_response);
            view.attach(license_view, 0, 1, 1, 1);
        } else if (license == null && gumroad_license_view != null) {
            view.remove(gumroad_license_view);
            gumroad_license_view.response.disconnect(on_gumroad_license_view_response);
            gumroad_license_view = null;
        } else if (license != null && gumroad_license_view.license != license) {
            gumroad_license_view.update(license);
        }

        bool purchase = license == null;
        bool upgrade = false;
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
            phase = Phase.LICENSE_KEY;
            enter_license_key(false);
            break;
        case MainAction.UPGRADE:
            paywall.open_upgrade_page();
            break;
        case MainAction.DEVELOPER:
            phase = Phase.DEVELOPER_KEY;
            enter_license_key(true);
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

    private void enter_license_key(bool developer) {
        phase = developer ? Phase.DEVELOPER_KEY : Phase.LICENSE_KEY;

        if (license_key_view != null) {
            if (license_key_view.get_parent() != null) {
                remove(license_key_view);
            }
            license_key_view.response.disconnect(on_license_key_view_response);
            license_key_view = null;
        }

        Gtk.Label label;
        if (developer) {
            label = Drtgtk.Labels.markup(
                "<b>Enter the developer license key:</b>\n\n"
                + "If you cannot find the key, contact "
                + "<a href=\"mailto:support@tiliado.eu\">support@tiliado.eu</a>."
            );
        } else {
            label = Drtgtk.Labels.markup(
                "<b>Enter the license key:</b>\n\nIt can be found in "
                + "<a href=\"https://www.gumroad.com/library\">your Gumroad library</a> "
                + "or your email receipt from Gumroad (it should arrive within a few minutes after the purchase, "
                + "please look into the spam folder too). If you cannot find the key, contact "
                + "<a href=\"mailto:support@tiliado.eu\">support@tiliado.eu</a>."
            );
        }
        license_key_view = new View(label, {"Continue", "Help", "Cancel"}, 0, {new Gtk.Entry()});
        license_key_view.response.connect(on_license_key_view_response);

        switch_view(license_key_view);
        var entry = (Gtk.Entry) license_key_view.extra_widgets[0];
        if (Drt.String.is_empty(entry.get_text())) {
            TiliadoLicense? license = paywall.get_gumroad_license();
            if (license != null) {
                entry.set_text(license.license.license_key);
            }
        }
        entry.grab_focus();
    }

    private void on_license_key_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            if (!fetch_license_key_details()) {
                license_key_view.extra_widgets[0].grab_focus();
            }
            break;
        case 1:
            paywall.show_help_page();
            break;
        default:
            reset();
            break;
        }
    }

    private bool fetch_license_key_details() {
        var entry = license_key_view.extra_widgets[0] as Gtk.Entry;
        string key = entry.text.strip();
        if (key == "") {
            return false;
        }
        if (verifying_gumroad_license_view == null) {
            verifying_gumroad_license_view = new View(
                Drtgtk.Labels.markup("The validity of the license key is being verified."),
                {"Help", "Cancel"});
            verifying_gumroad_license_view.response.connect(on_verifying_gumroad_license_view_response);
        }
        switch_view(verifying_gumroad_license_view);
        paywall.verify_gumroad_license(key);
        return true;
    }

    private void on_verifying_gumroad_license_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.show_help_page();
            break;
        default:
            enter_license_key(phase == Phase.DEVELOPER_KEY);
            break;
        }
    }

    private void on_license_invalid_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.show_help_page();
            break;
        default:
            enter_license_key(phase == Phase.DEVELOPER_KEY);
            break;
        }
    }

    private void on_license_failure_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            fetch_license_key_details();
            break;
        case 1:
            paywall.show_help_page();
            break;
        default:
            enter_license_key(phase == Phase.DEVELOPER_KEY);
            break;
        }
    }

    private void on_gumroad_license_verification_failed(string? reason) {
        if (license_failure_view == null) {
            license_failure_view = new View(
                Drtgtk.Labels.markup("Fail."),
                {"Try again", "Help", "Back"});
            license_failure_view.response.connect(on_license_failure_view_response);
        }
        license_failure_view.text_label.set_markup(Markup.printf_escaped(
            "Failed to verify the license key:\n\n%s", reason));
        switch_view(license_failure_view);
    }

    private void on_gumroad_license_invalid() {
        if (license_invalid_view == null) {
            license_invalid_view = new View(
                Drtgtk.Labels.markup("Your license key is not valid."),
                {"Help", "Back"});
            license_invalid_view.response.connect(on_license_invalid_view_response);
        }
        switch_view(license_invalid_view);
    }

    private void on_gumroad_license_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            warning("enter key for %s", TiliadoMembership.DEVELOPER.get_label());
            enter_license_key(paywall.get_gumroad_license_tier() >= TiliadoMembership.DEVELOPER);
            break;
        case 1:
            paywall.drop_gumroad_license();
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
            text_label.max_width_chars = 40;
            text_label.justify = Gtk.Justification.FILL;
            attach(text_label, 0, line++, 1, 1);

            if (extra_widgets != null) {
                foreach (unowned Gtk.Widget? widget in extra_widgets) {
                    if (widget != null) {
                        attach(widget, 0, line, 1, 1);
                    }
                    line++;
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

    private class Info : Gtk.Grid {
        public Gtk.Button?[]? buttons;
        protected unowned Gtk.Label? details = null;

        public Info(string title, owned string?[]? icon_buttons=null) {
            hexpand = false;
            vexpand = true;
            valign = halign = Gtk.Align.FILL;
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
            Gtk.Label header = Drtgtk.Labels.markup("<b>%s</b>", title);
            header.xalign = 0.5f;
            header.halign = Gtk.Align.START;
            header.yalign = 0.5f;
            attach(header, 0, line, 1, 1);
            var details = new Gtk.Label("");
            details.xalign = 0.0f;
            details.halign = Gtk.Align.START;
            details.use_markup = true;
            details.set_line_wrap(true);
            details.max_width_chars = 30;
            this.details = details;
            attach(details, 0, ++line, n_icons + 1, 1);
            show_all();
        }

        ~Info() {
            foreach (unowned Gtk.Button? button in buttons) {
                if (button != null) {
                    button.clicked.disconnect(on_button_clicked);
                }
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

    private class GumroadLicenseView : Info {
        public unowned TiliadoLicense? license = null;

        public GumroadLicenseView(TiliadoLicense license, owned string?[]? icon_buttons=null) {
            base("License key", (owned) icon_buttons);
            update(license);
        }

        public void update(TiliadoLicense license) {
            unowned string? description = null;
            TiliadoMembership tier = license.effective_tier;
            if (tier >= TiliadoMembership.DEVELOPER) {
                description = "Thank you for your work.";
            } else if (tier > TiliadoMembership.NONE) {
                description = "Thank you for purchasing Nuvola.";
            } else {
                description = license.get_reason() ?? "License key has been canceled.";
            }
            details.label = Markup.printf_escaped(
                "<i>%s</i>\n\nOwner: %s\nProduct: <a href=\"%s\">%s</a>\nTier: %s",
                description,
                license.license.full_name ?? license.license.email,
                license.license.product_link ?? "https://nuvola.tiliado.eu/pricing/",
                license.license.product_name,
                license.license_tier.get_label()
            );
            this.license = license;
            details.show();
        }
    }

    private enum Phase {
        NONE,
        DEVELOPER_KEY,
        LICENSE_KEY;
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
