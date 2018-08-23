/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 * Graphical representation of {@link StartupCheck}.
 */
public class StartupView : Gtk.ScrolledWindow {
    [Description (nick="XDG Desktop Portal status", blurb="XDG Desktop Portal is required for proxy settings and opening URIs.")]
    public Gtk.Label xdg_desktop_portal_status {get; set;}
    [Description (nick="XDG Desktop Portal message", blurb="Null unless the check went wrong.")]
    public Gtk.Label xdg_desktop_portal_message {get; set;}
    [Description (nick="Nuvola Service status", blurb="Status of the connection to Nuvola Service (master process).")]
    public Gtk.Label nuvola_service_status {get; set;}
    [Description (nick="Nuvola Service message", blurb="Null unless the check went wrong.")]
    public Gtk.Label nuvola_service_message {get; set;}
    [Description (nick="OpenGL driver status", blurb="If OpenGL driver is misconfigured, WebKitGTK may crash.")]
    public Gtk.Label opengl_driver_status {get; set;}
    [Description (nick="OpenGL driver message", blurb="Null unless the check went wrong.")]
    public Gtk.Label opengl_driver_message {get; set;}
    [Description (nick="VA-API driver status", blurb="One of the two APIs for video acceleration.")]
    public Gtk.Label vaapi_driver_status {get; set;}
    [Description (nick="VA-API driver message", blurb="Null unless the check went wrong.")]
    public Gtk.Label vaapi_driver_message {get; set;}
    [Description (nick="VDPAU driver status", blurb="One of the two APIs for video acceleration.")]
    public Gtk.Label vdpau_driver_status {get; set;}
    [Description (nick="VDPAU driver message", blurb="Null unless the check went wrong.")]
    public Gtk.Label vdpau_driver_message {get; set;}
    [Description (nick="Web App Requirements status", blurb="A web app may have certain requirements, e.g. Flash plugin, MP3 codec, etc.")]
    public Gtk.Label app_requirements_status {get; set;}
    [Description (nick="Web App Requirements message", blurb="Null unless the check went wrong.")]
    public Gtk.Label app_requirements_message {get; set;}
    #if TILIADO_API
    public Gtk.Label tiliado_account_status {get; set;}
    public Gtk.Label tiliado_account_message {get; set;}
    #endif
    [Description (nick="Startup checks", blurb="Model for this window.")]
    public StartupResult model {get; private set;}

    private Gtk.Grid grid;

    private int grid_line = 2;

    private unowned AppRunnerController app;

    /**
     * Create new StartupWindow
     *
     * @param app              The corresponding application.
     * @param startup_check    Startup checks.
     */
    public StartupView(AppRunnerController app, StartupResult model) {
        this.model = model;
        this.app = app;
        grid = new Gtk.Grid();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.column_spacing = grid.row_spacing = 10;
        grid.margin = 20;

        add_line(ref grid_line, "Web App Requirements", "app_requirements");
        add_line(ref grid_line, "Nuvola Service", "nuvola_service");
        add_line(ref grid_line, "XDG Desktop Portal", "xdg_desktop_portal");
        add_line(ref grid_line, "OpenGL Driver", "opengl_driver");
        add_line(ref grid_line, "VA-API Driver", "vaapi_driver");
        add_line(ref grid_line, "VDPAU Driver", "vdpau_driver");
        #if TILIADO_API
        add_line(ref grid_line, "Tiliado Account", "tiliado_account");
        #endif
        model.notify.connect_after(on_model_changed);
        set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        hexpand = vexpand = true;
        add(grid);
        show_all();
    }

    private void add_line(ref int line, string header, string name) {
        StartupStatus status = StartupStatus.UNKNOWN;
        string? msg = null;
        string prop_status = name.replace("_", "-") + "-status";
        string prop_msg = name.replace("_", "-") + "-message";
        model.get(prop_status, out status, prop_msg, out msg);
        Gtk.Label label = Drtgtk.Labels.header(header);
        label.show();
        label.set_line_wrap(false);
        grid.attach(label, 0, line, 1, 1);
        label = Drtgtk.Labels.plain(status.get_blurb());
        label.hexpand = false;
        label.halign = label.valign = Gtk.Align.CENTER;
        label.get_style_context().add_class(status.get_badge_class());
        label.show();
        grid.attach(label, 1, line, 1, 1);
        this.set(prop_status, label);
        label = Drtgtk.Labels.markup(msg);
        label.selectable = true;
        if (msg != null) {
            label.show();
            warning("%s: %s", name, msg);
        }
        grid.attach(label, 0, line + 1, 2, 1);
        this.set(prop_msg, label);
        line += 2;
    }

    private void on_model_changed(GLib.Object model, ParamSpec param) {
        if (param.name.has_suffix("-status") && param.name != "final-status") {
            StartupStatus status = StartupStatus.UNKNOWN;
            model.get(param.name, out status);
            Gtk.Label label = null;
            this.get(param.name, out label);
            label.label = status.get_blurb();
            Gtk.StyleContext styles = label.get_style_context();
            foreach (StartupStatus item in StartupStatus.all()) {
                styles.remove_class(item.get_badge_class());
            }
            styles.add_class(status.get_badge_class());
        } else if (param.name.has_suffix("-message")) {
            string? msg = null;
            model.get(param.name, out msg);
            Gtk.Label label = null;
            this.get(param.name, out label);
            label.label = msg;
            if (msg != null) {
                label.show();
                warning("%s: %s", param.name, msg);
            } else {
                label.hide();
            }
        }
    }
}

} // namespace Nuvola
