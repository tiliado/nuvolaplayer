/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class ScriptOverlayDialog : Drtgtk.OverlayNotification {
    public ScriptDialogModel model {get; private set;}
    public Gtk.Image? snapshot {get; set;}

    public ScriptOverlayDialog(ScriptDialogModel model) {
        base(null);
        this.model = model;
        Gtk.Label label = Drtgtk.Labels.markup("<b>Web App Alert</b>\n\nThe web page '%s' says:\n\n%s", model.url, model.message);
        add_child(label);
        label.show();
        if (model.snapshot != null) {
            var image = new Gtk.Image.from_pixbuf(model.snapshot);
            image.vexpand = image.hexpand = true;
            image.valign = image.halign = Gtk.Align.FILL;
            image.show();
            snapshot = image;
        }
    }

    public override void response (int response_id) {
        model.close();
        if (snapshot != null) {
            Gtk.Container parent = snapshot.get_parent();
            if (parent != null) {
                parent.remove(snapshot);
            }
        }
        hide();
        dispose();
    }
}

} // namespace Nuvola
