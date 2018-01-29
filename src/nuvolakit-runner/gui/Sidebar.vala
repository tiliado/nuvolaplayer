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

public class Sidebar : Gtk.Grid {
    public signal void page_changed();
    public string? page {
        get {return stack.visible_child_name;}
        set {stack.visible_child_name = value;}
    }

    private Gtk.Stack stack;
    private Drtgtk.StackMenuButton header;

    public Sidebar() {
        stack = new Gtk.Stack();
        stack.expand = true;
        stack.margin = 8;
        stack.show();
        stack.notify["visible-child-name"].connect_after(on_page_changed);
        header = new Drtgtk.StackMenuButton(stack);
        header.stack = stack;
        header.show();
        header.hexpand = true;
        header.halign = Gtk.Align.FILL;
        header.margin = 8;
        var button = new Gtk.Button.from_icon_name("window-close-symbolic", Gtk.IconSize.BUTTON);
        button.relief = Gtk.ReliefStyle.NONE;
        button.clicked.connect(on_close_button_clicked);
        button.margin = 8;
        button.show();
        button.hexpand = false;
        attach(header, 0, 0, 1, 1);
        attach(button, 1, 0, 1, 1);
        attach(stack, 0, 1, 2, 1);
        vexpand = hexpand = true;
    }

    public override void show() {
        if (is_empty()) {
            return;
        }
        base.show();
    }

    public virtual signal void add_page(string name, string label, Gtk.Widget page) {
        stack.add_titled(page, name, label);
        page.show();
        show();
    }

    public virtual signal void remove_page(Gtk.Widget page) {
        stack.remove(page);
        if (is_empty()) {
            hide();
        }
    }

    public bool is_empty() {
        return stack.visible_child == null;
    }

    private void on_close_button_clicked() {
        hide();
    }

    private void on_page_changed(GLib.Object o, ParamSpec p) {
        page_changed();
    }
}

} // namespace Nuvola
