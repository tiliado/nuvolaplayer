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
    private View? purchase_options_view = null;
    private View? license_key_view = null;
    private View? verifying_gumroad_license_view = null;
    private GumroadLicenseView? gumroad_license_view = null;
    private MachineTrialView? machine_trial_view = null;
    private View? license_failure_view = null;
    private View? license_invalid_view = null;
    private bool activation_pending = false;

    public TiliadoPaywallWidget(TiliadoPaywall paywall) {
        this.paywall = paywall;
        paywall.tier_info_updated.connect(on_tier_info_updated);
        paywall.connecting_tiliado_account.connect(on_connecting_tiliado_account);
        paywall.tiliado_account_linking_cancelled.connect(on_tiliado_account_linking_cancelled);
        paywall.tiliado_account_linking_failed.connect(on_tiliado_account_linking_failed);
        paywall.tiliado_account_linking_finished.connect(on_tiliado_account_linking_finished);
        paywall.gumroad_license_verification_failed.connect(on_gumroad_license_verification_failed);
        paywall.gumroad_license_invalid.connect(on_gumroad_license_invalid);

        main_view = new View(null, {
            "Purchase Nuvola Runtime",
            "I purchased Nuvola Runtime",
            "Upgrade tier",
            "I have Tiliado Developer account",
            "Help",
            "Close"}, 0, {null, null, null});
        main_view.response.connect(on_main_view_response);
        reset();
    }

    ~TiliadoPaywallWidget() {
        paywall.tier_info_updated.disconnect(on_tier_info_updated);
        paywall.connecting_tiliado_account.disconnect(on_connecting_tiliado_account);
        paywall.tiliado_account_linking_cancelled.disconnect(on_tiliado_account_linking_cancelled);
        paywall.tiliado_account_linking_failed.disconnect(on_tiliado_account_linking_failed);
        paywall.tiliado_account_linking_finished.disconnect(on_tiliado_account_linking_finished);
        paywall.gumroad_license_verification_failed.disconnect(on_gumroad_license_verification_failed);
        paywall.gumroad_license_invalid.disconnect(on_gumroad_license_invalid);
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
            view.attach(account_view, 0, 2, 1, 1);
        } else if (user == null && tiliado_account_view != null) {
            view.remove(tiliado_account_view);
            tiliado_account_view.response.disconnect(on_tiliado_account_view_response);
            tiliado_account_view = null;
        } else if (user != null && tiliado_account_view.user != user) {
            tiliado_account_view.update(user);
        }

        TiliadoLicense? license = paywall.get_gumroad_license();
        if (license != null && gumroad_license_view == null) {
            var license_view = new GumroadLicenseView(license, {"view-refresh-symbolic", "user-trash-symbolic"});
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

        MachineTrial? trial = paywall.get_trial();
        bool in_trial = trial != null && paywall.get_gumroad_license_tier() + paywall.get_tiliado_account_tier() == 0;
        if ((trial == null || !in_trial) && machine_trial_view != null) {
            view.remove(machine_trial_view);
            machine_trial_view = null;
        } else if (in_trial && machine_trial_view == null) {
            var trial_view = new MachineTrialView(trial);
            machine_trial_view = trial_view;
            view.attach(trial_view, 0, 0, 1, 1);
        } else if (trial != null && machine_trial_view != null && machine_trial_view.trial != trial) {
            machine_trial_view.update(trial);
        }

        bool purchase = paywall.tier == TiliadoMembership.NONE || in_trial;
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
            choose_purchase_option();
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

    private void choose_purchase_option() {
        if (purchase_options_view == null) {
            Gtk.Widget[] options = new Gtk.Widget[2];
            options[0] = new Gtk.RadioButton.with_label_from_widget(null,
                "I purchased Nuvola Runtime and received a license key.");
            options[1] = new Gtk.RadioButton.with_label_from_widget(
                options[0] as Gtk.RadioButton,
                "I haven't received any license key, but my purchase was linked to my Tiliado account.");
            foreach (unowned Gtk.Widget widget in options) {
                var label = ((Gtk.Bin) widget).get_child() as Gtk.Label;
                label.wrap = true;
                label.max_width_chars = 20;
            }
            purchase_options_view = new View(
                Drtgtk.Labels.markup("<b>Have you received a license key?</b>"),
                {"Continue", "Help", "Cancel"}, 0, (owned) options);
            purchase_options_view.response.connect(on_purchase_options_view_response);
        }
        switch_view(purchase_options_view);
    }

    private void on_purchase_options_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            if (((Gtk.RadioButton) purchase_options_view.extra_widgets[0]).active) {
                phase = Phase.LICENSE_KEY;
                enter_license_key();
            } else {
                phase = Phase.TILIADO_ACCOUNT;
                show_purchase_confirmation_needed();
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
            choose_purchase_option();
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

    private void enter_license_key() {
        if (license_key_view == null) {
            license_key_view = new View(
                Drtgtk.Labels.markup("Enter the license key:"),
                {"Continue", "Help", "Cancel"}, 0, {new Gtk.Entry()});
            license_key_view.response.connect(on_license_key_view_response);
        }
        switch_view(license_key_view);
        license_key_view.extra_widgets[0].grab_focus();
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
            choose_purchase_option();
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
            enter_license_key();
            break;
        }
    }

    private void on_license_invalid_view_response(int index, Gtk.Button button) {
        switch (index) {
        case 0:
            paywall.show_help_page();
            break;
        default:
            enter_license_key();
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
            enter_license_key();
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
            enter_license_key();
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
            text_label.max_width_chars = 30;
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
            Gtk.Label header = Drtgtk.Labels.markup("<b>%s</b>", title);
            header.xalign = 0.5f;
            header.halign = Gtk.Align.CENTER;
            header.yalign = 0.5f;
            attach(header, 0, line, 1, 1);
            var details = new Gtk.Label("");
            details.xalign = 0.5f;
            details.halign = Gtk.Align.CENTER;
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

    private class TiliadoAccountView : Info {
        public unowned TiliadoApi2.User? user = null;

        public TiliadoAccountView(TiliadoApi2.User user, owned string?[]? icon_buttons=null) {
            base("Tiliado Account", (owned) icon_buttons);
            update(user);
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
            details.show();
        }
    }

    private class GumroadLicenseView : Info {
        public unowned TiliadoLicense? license = null;

        public GumroadLicenseView(TiliadoLicense license, owned string?[]? icon_buttons=null) {
            base("Gumroad License", (owned) icon_buttons);
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
                description = "License key is not valid.";
            }
            details.label = Markup.printf_escaped(
                "<i>%s</i>\n\nProduct: <a href=\"%s\">%s</a>\nTier: %s", description,
                "https://gum.co/" + license.license.product_id, license.license.product_name,
                license.license_tier.get_label());
            this.license = license;
            details.show();
        }
    }

    private class MachineTrialView : Info {
        public unowned MachineTrial? trial = null;

        public MachineTrialView(MachineTrial trial) {
            base("Free Trial", null);
            update(trial);
        }

        public void update(MachineTrial trial) {
            TiliadoMembership tier = trial.tier;
            string started = Drt.Utils.human_datetime(trial.created);
            string expires = Drt.Utils.human_datetime(trial.expires);
            if (trial.has_expired()) {
                details.label = Markup.printf_escaped(
                    "<i>%s</i>\n\nName: %s\nTier: %s\nStarted: %s\nExpired: %s",
                    "Your trial has expired.",
                    trial.name, tier.get_label(), started, expires);
            } else {
                details.label = Markup.printf_escaped(
                    "<i>%s</i>\n\nName: %s\nTier: %s\nStarted: %s\nExpires: %s",
                    "Try Nuvola features for free before purchasing.",
                    trial.name, tier.get_label(), started, expires);
            }
            this.trial = trial;
            details.show();
        }
    }

    private enum Phase {
        NONE,
        DEVELOPER_ACCOUNT,
        TILIADO_ACCOUNT,
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
