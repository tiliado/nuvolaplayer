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
    public bool mute_on_headphones_disconnect {get; set; default = false;}
    public bool pause_on_headphones_disconnect {get; set; default = false;}
    public bool play_on_headphones_connect {get; set; default = false;}
    private AppRunnerController controller;
    private Bindings bindings;
    private AudioClient? audio_client = null;
    private HeadPhonesWatch? headphones_watch = null;

    public AudioTweaksComponent(AppRunnerController controller, Bindings bindings, Drt.KeyValueStorage config) {
        base(config, "audio_tweaks", "Audio Tweaks", "Tweaks for PulseAudio integration.", "audio_tweaks");
        this.premium = true;
        this.has_settings = true;
        this.bindings = bindings;
        this.controller = controller;
        bind_config_property("mute_on_headphones_disconnect", false);
        bind_config_property("pause_on_headphones_disconnect", false);
        bind_config_property("play_on_headphones_connect", false);
    }

    protected override bool activate() {
        if (audio_client == null) {
            audio_client = new AudioClient();
            audio_client.start();
        }
        headphones_watch = new HeadPhonesWatch(audio_client);
        headphones_watch.notify["headphones-plugged"].connect_after(on_headphones_plugged_changed);
        return true;
    }

    protected override bool deactivate() {
        headphones_watch.notify["headphones-plugged"].disconnect(on_headphones_plugged_changed);
        headphones_watch = null;
        audio_client.global_mute = false;
        return true;
    }

    public override Gtk.Widget? get_settings() {
        return new AudioTweaksSettings(this);
    }

    private void on_headphones_plugged_changed(GLib.Object o, ParamSpec p) {
        debug("Headphones plugged in: %s", headphones_watch.headphones_plugged.to_string());
        if (mute_on_headphones_disconnect) {
            if (headphones_watch.headphones_plugged == audio_client.global_mute) {
                audio_client.global_mute = !headphones_watch.headphones_plugged;
            }
        }
        if (pause_on_headphones_disconnect && !headphones_watch.headphones_plugged) {
            Drtgtk.Action? action = controller.actions.get_action("pause");
            if (action != null) {
                action.activate(null);
            }
        }
        if (play_on_headphones_connect && headphones_watch.headphones_plugged) {
            Drtgtk.Action? action = controller.actions.get_action("play");
            if (action != null) {
                action.activate(null);
            }
        }
    }
}

public class AudioTweaksSettings : Gtk.Grid {
    private Gtk.Switch mute_on_headphones_disconnect;
    private Gtk.Switch pause_on_headphones_disconnect;
    private Gtk.Switch play_on_headphones_connect;

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

        line++;
        label = Drtgtk.Labels.plain("Pause playback when headphones are unplugged.");
        attach(label, 1, line, 1, 1);
        label.show();
        pause_on_headphones_disconnect = new Gtk.Switch();
        component.bind_property("pause-on-headphones-disconnect", pause_on_headphones_disconnect, "active", bind_flags);
        attach(pause_on_headphones_disconnect, 0, line, 1, 1);
        pause_on_headphones_disconnect.show();

        line++;
        label = Drtgtk.Labels.plain("Resume playback when headphones are plugged.");
        attach(label, 1, line, 1, 1);
        label.show();
        play_on_headphones_connect = new Gtk.Switch();
        component.bind_property("play-on-headphones-connect", play_on_headphones_connect, "active", bind_flags);
        attach(play_on_headphones_connect, 0, line, 1, 1);
        play_on_headphones_connect.show();
    }
}

} // namespace Nuvola
