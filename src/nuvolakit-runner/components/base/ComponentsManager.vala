/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class ComponentsManager : PreferencesDialog.SelectorGroup {
    private unowned SList<Component> components;
    private Gtk.Widget component_not_available_widget;
    public UpgradeRequiredWidget? membership_widget = null;
    private TiliadoPaywall? paywall = null;
    public TiliadoTierWidget? tier_widget = null;

    public ComponentsManager(Drtgtk.Application app, SList<Component> components, TiliadoPaywall? paywall) {
        base(null, null);
        this.components = components;
        this.paywall = paywall;
        component_not_available_widget = Drtgtk.Labels.markup(
            "Your distributor has not enabled this feature. It is available in <a href=\"%s\">the genuine flatpak "
            + "builds of Nuvola Apps Runtime</a> though.", "https://nuvola.tiliado.eu");
        add_components_to_group();
        if (paywall != null) {
            tier_widget = new TiliadoTierWidget(paywall);
            tier_widget.show();
            extra_widget = tier_widget;
            membership_widget = new UpgradeRequiredWidget(paywall);
            membership_widget.paywall_widget.close.connect(on_paywall_widget_closed);
            paywall.notify.connect_after(on_membership_changed);
        }
    }

    ~ComponentsManager() {
        if (paywall != null) {
            paywall.notify.disconnect(on_membership_changed);
        }
    }

    public void refresh() {
        foreach (unowned PreferencesDialog.Panel item in panels) {
            var panel = item as Panel;
            if (panel != null) {
                panel.refresh();
            }
        }
    }

    public int component_sort_func(Component a, Component b) {
        bool a_available = is_component_available(a);
        bool b_available = is_component_available(b);
        return (a_available != b_available) ? (a_available ? -1 : 1) : strcmp(a.name, b.name);
    }

    public override int sort_list_box(Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        return component_sort_func(
            ((Panel) ((PreferencesDialog.Row) row1).panel).component,
            ((Panel) ((PreferencesDialog.Row) row2).panel).component);
    }

    private void add_components_to_group() {
        foreach (unowned Component component in components) {
            if (component.hidden && !component.enabled) {
                continue;
            }
            add(new Panel(this, component));
        }
    }

    public Gtk.Widget? get_alert_widget(Component component) {
        Gtk.Widget? widget = null;
        if (!is_component_membership_ok(component)) {
            widget = membership_widget;
        } else if (!is_component_available(component)) {
            widget = create_component_not_available_widget(component);
        }
        return widget;
    }

    private Gtk.Widget create_component_not_available_widget(Component component) {
        Gtk.Widget? widget = component.get_unavailability_widget();
        if (widget == null) {
            string? reason = component.get_unavailability_reason();
            if (reason != null) {
                widget = Drtgtk.Labels.markup(reason);
            }
        }
        return widget ?? component_not_available_widget;
    }

    private bool is_component_available(Component component) {
        /* If component was enabled before sufficient membership was lost, let it be. */
        return component.enabled || component.available && component.is_membership_ok(paywall);
    }

    private bool is_component_membership_ok(Component component) {
        return (component.enabled || !component.available
        || paywall == null || component.is_membership_ok(paywall));
    }

    private void on_membership_changed(GLib.Object emitter, ParamSpec param) {
        switch (param.name) {
        case "tier":
            refresh();
            panel_closed();
            break;
        }
    }

    private void on_paywall_widget_closed(TiliadoPaywallWidget paywall_widget) {
        panel_closed();
    }

    private class Panel : PreferencesDialog.Panel {
        private unowned ComponentsManager manager;
        public unowned Component component;

        public Panel(ComponentsManager manager, Component component) {
            this.component = component;
            this.manager = manager;
            has_help = get_help_url() != null;
            is_toggle = true;
            refresh();
            notify.connect_after(on_notify);
            component.notify.connect_after(on_component_notify);
        }

        public void refresh() {
            is_enabled = component.enabled;
            bool available = manager.is_component_available(component);
            if (is_available != available) {
                is_available = available;
            }
            has_alert = !available;
            has_widget = component.has_settings;

        }

        private Gtk.Widget? adjust_margin(Gtk.Widget? widget) {
            if (widget != null) {
                widget.margin_top = 15;
                widget.margin_bottom = 15;
                widget.margin_start = 20;
                widget.margin_end = 20;
            }
            return widget;
        }

        public override Gtk.Widget? get_widget() {
            return adjust_margin(component.get_settings());
        }

        public override Gtk.Widget? get_alert_widget() {
            return adjust_margin(manager.get_alert_widget(component));
        }

        public override unowned string get_title() {
            return component.name;
        }

        public override unowned string? get_subtitle() {
            return component.description;
        }

        public override unowned string? get_help_url() {
            return component.help_url;
        }

        private void on_component_notify(GLib.Object emitter, ParamSpec param) {
            switch (param.name) {
            case "enabled":
                if (is_enabled != component.enabled) {
                    is_enabled = component.enabled;
                }
                break;
            }
        }

        private void on_notify(GLib.Object emitter, ParamSpec param) {
            switch (param.name) {
            case "is-enabled":
                component.toggle(is_enabled);
                break;
            }
        }
    }
}

} // namespace Nuvola
