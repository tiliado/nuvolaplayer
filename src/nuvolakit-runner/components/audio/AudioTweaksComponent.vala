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

public class AudioTweaksComponent: Component {
    private const string NAMESPACE = "component.audio_tweaks.";
    public bool mute_on_headphones_disconnect {get; set; default = false;}
    private AppRunnerController controller;
    private Bindings bindings;
    private AudioClient? audio_client = null;
    private HeadPhonesWatch? headphones_watch = null;

    public AudioTweaksComponent(AppRunnerController controller, Bindings bindings, Drt.KeyValueStorage config) {
        base("audio_tweaks", "Audio Tweaks (beta)", "Tweaks for PulseAudio integration.");
        this.required_membership = TiliadoMembership.PREMIUM;
        this.has_settings = false;
        this.bindings = bindings;
        this.controller = controller;
        config.bind_object_property(NAMESPACE, this, "enabled").set_default(false).update_property();
        config.bind_object_property(NAMESPACE, this, "mute_on_headphones_disconnect")
        .set_default(false).update_property();
    }

    protected override bool activate() {
        if (audio_client == null) {
            audio_client = new AudioClient();
            audio_client.start();
        }
        headphones_watch = new HeadPhonesWatch(audio_client);
        return true;
    }

    protected override bool deactivate() {
        headphones_watch = null;
        return true;
    }

    public override Gtk.Widget? get_settings() {
        return new AudioTweaksSettings(this);
    }
}

public class AudioTweaksSettings : Gtk.Grid {
    private Gtk.Switch mute_on_headphones_disconnect;

    public AudioTweaksSettings(AudioTweaksComponent component) {
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 10;
        column_spacing = 10;
        var line = 0;
        BindingFlags bind_flags = BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE;
        Gtk.Label label = Drtgtk.Labels.plain("Mute audio when headphones are unplugged.");
        attach(label, 1, line, 1, 1);
        label.show();
        mute_on_headphones_disconnect = new Gtk.Switch();
        component.bind_property("mute-on-headphones-disconnect", mute_on_headphones_disconnect, "active", bind_flags);
        attach(mute_on_headphones_disconnect, 0, line, 1, 1);
        mute_on_headphones_disconnect.show();
    }
}

} // namespace Nuvola
