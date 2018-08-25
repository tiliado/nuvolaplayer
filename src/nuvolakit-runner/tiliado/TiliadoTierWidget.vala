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

public class TiliadoTierWidget : Gtk.Grid {
    private TiliadoPaywall paywall;
    private Gtk.Label label;
    private Gtk.Button paywall_button;
    private Gtk.Button upgrade_button;

    public TiliadoTierWidget(TiliadoPaywall paywall) {
        this.paywall = paywall;
        no_show_all = true;
        margin = 5;
        row_spacing = column_spacing = 5;
        orientation = Gtk.Orientation.HORIZONTAL;
        hexpand = false;
        vexpand = false;
        halign = Gtk.Align.CENTER;
        label = Drtgtk.Labels.markup("Tier");
        label.halign = Gtk.Align.CENTER;
        label.valign = Gtk.Align.CENTER;
        label.hexpand = false;
        label.vexpand = false;
        label.margin_end = 10;
        label.margin_start = 10;
        label.show();
        add(label);
        var button = new Gtk.Button();
        button.hexpand = false;
        button.vexpand = false;
        button.halign = Gtk.Align.CENTER;
        button.valign = Gtk.Align.CENTER;
        button.clicked.connect(on_paywall_button_clicked);
        button.show();
        paywall_button = button;
        add(button);
        button = new Gtk.Button.with_label("Upgrade");
        button.hexpand = false;
        button.vexpand = false;
        button.halign = Gtk.Align.CENTER;
        button.valign = Gtk.Align.CENTER;
        button.no_show_all = true;
        button.clicked.connect(paywall.open_upgrade_page);
        upgrade_button = button;

        add(button);
        update();
        paywall.notify.connect_after(on_paywall_changed);

    }

    public signal void show_paywall(TiliadoPaywall paywall);

    ~TiliadoTierWidget() {
        paywall_button.clicked.disconnect(on_paywall_button_clicked);
        paywall.notify.disconnect(on_paywall_changed);
        upgrade_button.clicked.disconnect(paywall.open_upgrade_page);
    }

    private void on_paywall_button_clicked() {
        show_paywall(paywall);
    }

    private void on_paywall_changed(GLib.Object emitter, ParamSpec param) {
        update();
    }

    private void update() {
        if (paywall.tier < TiliadoMembership.BASIC) {
            upgrade_button.hide();
            paywall_button.label = "Unlock features";
            paywall_button.get_style_context().add_class("suggested-action");
        } else {
            paywall_button.label = "Info";
            paywall_button.get_style_context().remove_class("suggested-action");
            upgrade_button.visible = paywall.tier < TiliadoMembership.PREMIUM;
        }
        label.set_markup(Markup.printf_escaped("Features Tier: <b>%s</b>",
            paywall.unlocked ? paywall.tier.get_label() : "Free"));
    }
}

} // namespace Nuvola
