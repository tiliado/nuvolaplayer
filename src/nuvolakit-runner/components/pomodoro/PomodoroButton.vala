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

public class PomodoroDialog: Gtk.Dialog {
    private unowned PomodoroComponent pomodoro;
    private unowned Gtk.Grid grid;
    private unowned Gtk.Label top_label;
    private unowned Gtk.Label timer_label;

    public PomodoroDialog(Gtk.Window? parent, PomodoroComponent pomodoro) {
        this.pomodoro = pomodoro;
        var grid = new Gtk.Grid();

        Gtk.Label label = new Gtk.Label("");
        label.use_markup = true;
        grid.attach(label, 0, 0, 2, 1);
        grid.show_all();
        top_label = label;

        label = new Gtk.Label("");
        label.use_markup = true;
        grid.attach(label, 0, 1, 2, 1);
        timer_label = label;

        update_top_label();
        grid.show_all();
        get_content_area().add(grid);

    }

    public override bool delete_event(Gdk.EventAny event) {
        hide();
        return true;
    }

    private void update(string parameter) {
        switch (parameter) {
        case "pomodoros-elapsed":
        case "status":
            update_top_label();
            break;
        }
    }

    private void update_top_label() {
        string type = null;
        switch (pomodoro.status) {
        case STOPPED:
        case IN_PROGRESS:
        case PAUSED:
            type = "Pomodoro #%d".printf(pomodoro.pomodoros_elapsed + 1);
            break;
        case BREAK:
        case BREAK_PAUSED:
            type = "Short break";
            break;
        case LONG_BREAK:
        case LONG_BREAK_PAUSED:
            type = "Long break";
            break;
        }

        string format = null;
        switch (pomodoro.status) {
        default:
            format = "%s stopped";
            break;
        case IN_PROGRESS:
        case BREAK:
        case LONG_BREAK:
            format = "%s in progress";
            break;
        case PAUSED:
        case BREAK_PAUSED:
        case LONG_BREAK_PAUSED:
            format = "%s paused";
            break;
        }
        top_label.label = Markup.printf_escaped(format, type);
    }
}

} // namespace Nuvola
