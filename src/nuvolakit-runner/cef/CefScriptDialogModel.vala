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

public class CefScriptDialogModel : ScriptDialogModel {
    private Cef.JsdialogCallback? js_dialog_callback;

    public CefScriptDialogModel(
        Cef.JsdialogType cef_type, Cef.JsdialogCallback? js_dialog_callback,
        string? url, string? message, string? user_input = null, Gdk.Pixbuf? snapshot=null
    ) {
        base(translate_type(cef_type), url, message, user_input, snapshot);
        this.js_dialog_callback = js_dialog_callback;
    }

    public override void close() {
        assert(js_dialog_callback != null);
        Cef.String user_input = {};
        if (this.user_input != null) {
            Cef.set_string(&user_input, this.user_input);
        }
        js_dialog_callback.cont((int) this.result, &user_input);
        js_dialog_callback = null;
    }

    private static ScriptDialogType translate_type(Cef.JsdialogType cef_type) {
        switch (cef_type) {
        case Cef.JsdialogType.ALERT: return ScriptDialogType.ALERT;
        case Cef.JsdialogType.CONFIRM: return ScriptDialogType.CONFIRM;
        case Cef.JsdialogType.PROMPT: return ScriptDialogType.PROMPT;
        default: assert_not_reached(); break;
        }
    }
}

} // namespace Nuvola
