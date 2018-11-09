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

public class PomodoroComponent: Component {
    public int work_interval {get; set;}
    public int short_break {get; set;}
    public int long_break {get; set;}
    public int pomodoro_set {get; set;}
    public int pomodoros_elapsed {get; private set; default = 0;}
    public int timer_seconds {get; private set; default = 0;}
    public PomodoroStatus status {get; private set; default = PomodoroStatus.STOPPED;}
    private AppRunnerController controller;
    private Bindings bindings;
    private Gtk.Button? button = null;
    private PomodoroDialog? dialog = null;

    public PomodoroComponent(AppRunnerController controller, Bindings bindings, Drt.KeyValueStorage config) {
        base(config, "pomodoro", "Pomodoro Technique", "Play music during work intervals, pause musing during breaks.", "pomodoro");
        this.required_membership = TiliadoMembership.BASIC;
        this.has_settings = true;
        this.bindings = bindings;
        this.controller = controller;
        auto_activate = true;
        bind_config_property("work_interval", 25);
        bind_config_property("short_break", 5);
        bind_config_property("long_break", 15);
        bind_config_property("pomodoro_set", 4);
    }

    protected override bool activate() {
        WebAppWindow? window = controller.main_window;
        return_val_if_fail(window != null, false);
        var button = new Gtk.Button.with_label("");
        this.button = button;
        update_button_label();
        button.clicked.connect(show_dialog);
        window.header_bar.pack_end(button);
        return true;
    }

    protected override bool deactivate() {
        if (button != null) {
            button.clicked.disconnect(show_dialog);
            Gtk.Container? parent = button.get_parent();
            if (parent != null) {
                parent.remove(button);
                button = null;
            }
        }
        if (dialog != null) {
            dialog.destroy();
            dialog = null;
        }
        return true;
    }

    public override Gtk.Widget? get_settings() {
        return new PomodoroSettings(this);
    }

    private void update_button_label() {
        int pomodoros = this.pomodoros_elapsed;
        button.label = "Pomodoro: %d".printf(pomodoros + 1);
    }

    private void show_dialog() {
        PomodoroDialog? dialog = this.dialog;
        if (dialog == null) {
            this.dialog = dialog = new PomodoroDialog(controller.main_window, this);
        }
        dialog.present();
    }



}

public enum PomodoroStatus {
    STOPPED,
    IN_PROGRESS,
    PAUSED,
    BREAK,
    BREAK_PAUSED,
    LONG_BREAK,
    LONG_BREAK_PAUSED;
}

public class PomodoroSettings : Gtk.Grid {
    private Gtk.SpinButton work_interval;
    private Gtk.SpinButton short_break;
    private Gtk.SpinButton long_break;
    private Gtk.SpinButton pomodoro_set;
    private unowned PomodoroComponent component;

    public PomodoroSettings(PomodoroComponent component) {
        this.component = component;
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 10;
        column_spacing = 10;
        var line = 0;
        Gtk.Label label = Drtgtk.Labels.markup(
            "<a href=\"%s\">Pomodoro Technique</a> breaks down work into intervals (25 minutes) separated by short "
            + "breaks (5 minutes). These intervals are named <i>pomodoros</i>. Four pomodoros form a set, which "
            + "are separated by a longer break (15–30 minutes).\n\n"
            + "Some people are listening to music during their work to keep focused. This feature provides them with "
            + "a simple pomodoro timer which pauses music when a break starts and resumes it when the break ends.",
            "https://en.wikipedia.org/wiki/Pomodoro_Technique");
        attach(label, 0, line++, 3, 1);

        work_interval = add_spin_button(ref line, "work-interval", "Duration of one pomodoro: ", "minutes", 5.0, 8 * 60.0, 5.0);
        short_break = add_spin_button(ref line, "short-break", "Duration of short break: ", "minutes", 1.0, 8 * 60.0, 1.0);
        long_break = add_spin_button(ref line, "long-break", "Duration of long break: ", "minutes", 1.0, 8 * 60.0, 5.0);
        pomodoro_set = add_spin_button(ref line, "pomodoro-set", "Size of pomodoro set: ", "pomodoros", 1.0, 10.0, 1.0);
        show_all();
    }

    private Gtk.SpinButton add_spin_button(
        ref int line, string property, string legend, string? unit, double min, double max, double step
    ) {
        BindingFlags bind_flags = BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE;
        Gtk.Label label = Drtgtk.Labels.plain(legend);
        label.yalign = 0.5f;
        attach(label, 0, line, 1, 1);
        if (unit != null) {
            label = Drtgtk.Labels.plain(unit);
            label.yalign = 0.5f;
            label.hexpand = false;
            attach(label, 2, line, 1, 1);
        }

        var spin = new Gtk.SpinButton.with_range(min, max, step);
        spin.set_digits(0);
        component.bind_property(property, spin, "value", bind_flags);
        attach(spin, 1, line, 1, 1);
        line++;
        return spin;
    }
}

} // namespace Nuvola
