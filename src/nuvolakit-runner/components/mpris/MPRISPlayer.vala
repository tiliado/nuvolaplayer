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

[DBus(name = "org.mpris.MediaPlayer2.Player")]
public class MPRISPlayer : GLib.Object {
    private DBusConnection conn;
    private MediaPlayerModel player;
    private HashTable<string, Variant> pending_update;
    private uint pending_update_id = 0;

    public MPRISPlayer(MediaPlayerModel player, DBusConnection conn) {
        this.player = player;
        this.conn = conn;
        player.notify.connect_after((o, p) => {schedule_update(p.name);});
        metadata = create_metadata();
        position = player.track_position;
        _volume = player.volume;
        playback_status = map_playback_state();
        _loop_status = map_repeat_state_to_string(player.repeat);
        _shuffle = player.shuffle;
        pending_update = new HashTable<string, Variant>(str_hash, str_equal);
        can_go_next = player.can_go_next;
        can_go_previous = player.can_go_previous;
        can_seek = player.can_seek;
    }

    private string _loop_status = "None";
    public string loop_status {
        get { return _loop_status;}
        set {
            if (value != map_repeat_state_to_string(player.repeat)) {
                player.change_repeat(map_repeat_state_to_enum(value));
            }
        }
    }

    public string playback_status {get; private set; default = "None";}
    /* If the media player has no ability to play at speeds other than the normal playback rate,
     * this must still be implemented, and must return 1.0. The MinimumRate and MaximumRate properties
     * must also be set to 1.0.  A value of 0.0 set by the client should act as though Pause was called. */
    public double rate {
        get {
            return 1.0;
        }
        set {
            if (value == 0.0) {
                player.pause();
            }
        }
    }
    public double minimum_rate {get {return 1.0;}}
    public double maximum_rate {get {return 1.0;}}
    public int64 position {get; private set; default = 0;}
    public bool can_go_next {get; private set; default = false;}
    public bool can_go_previous {get; private set; default = false;}
    public bool can_seek {get; private set; default = false;}
    public bool can_control {get {return true;}}
    private bool _shuffle = false;
    public bool shuffle {
        get {return _shuffle;}
        set {
            if (player.shuffle != value) {
                player.change_shuffle(value);
            }
        }
    }
    public bool nuvola_can_rate {get; private set; default = false;}
    public HashTable<string, Variant> metadata {get; private set; default = null;}

    /*
     * CanPlay/CanPause MPRIS flags have different meaning than Player.can_pause flag in Nuvola Player!
     *
     * MPRIS: Whether playback can be started/paused using Play, Pause or PlayPause. Note that this is an intrinsic property of
     * the current track: its value should not depend on whether the track is currently paused or playing. In fact,
     * if playback is currently playing/paused (and CanControl is true), this should be true.
     *
     * Let it always be true: tiliado/nuvolaruntime#439
     */
    public bool can_play {get {return true;}}
    public bool can_pause {get {return true;}}

    private double _volume = 1.0;
    public double volume {
        get {return _volume;}
        set {player.change_volume(value < 0.0 ? 0.0 : value);}
    }

    public signal void seeked(int64 position);

    public void next() throws GLib.DBusError, GLib.IOError {
        player.next_song();
    }

    public void previous() throws GLib.DBusError, GLib.IOError {
        player.prev_song();
    }

    public void pause() throws GLib.DBusError, GLib.IOError {
        player.pause();
    }

    public void play_pause() throws GLib.DBusError, GLib.IOError {
        player.toggle_play();
    }

    public void stop() throws GLib.DBusError, GLib.IOError {
        player.stop();
    }

    public void play() throws GLib.DBusError, GLib.IOError {
        player.play();
    }

    public void seek(int64 offset) throws GLib.DBusError, GLib.IOError {
        if (can_seek) {
            player.seek(player.track_position + offset);
        }
    }

    public void SetPosition(ObjectPath track_id, int64 position) throws GLib.DBusError, GLib.IOError {
        player.seek(position);
    }

    public void open_uri(string uri) throws GLib.DBusError, GLib.IOError {
    }

    public void nuvola_set_rating(double rating) throws GLib.DBusError, GLib.IOError {
        player.set_rating(rating);
    }

    private void schedule_update(string param) {
        switch (param) {
        case "title":
        case "artist":
        case "album":
        case "artwork-file":
        case "rating":
        case "track-length":
            HashTable<string, Variant> new_metadata = create_metadata();
            if (new_metadata.size() == 0 && metadata.size() == 0) {
                return;
            }
            pending_update["Metadata"] = metadata = new_metadata;
            break;
        case "track-position":
            int64 delta = player.track_position - position;
            position = player.track_position;
            if (delta > 2000000 || delta < -2000000) {
                seeked(position);
                pending_update["Position"] = position;
            }
            break;
        case "volume":
            if (_volume != player.volume) {
                pending_update["Volume"] = _volume = player.volume;
            }
            break;
        case "repeat":
            unowned string repeat = map_repeat_state_to_string(player.repeat);
            if (_loop_status == repeat) {
                return;
            }
            pending_update["LoopStatus"] = _loop_status = repeat;
            break;
        case "shuffle":
            if (_shuffle == player.shuffle) {
                return;
            }
            pending_update["Shuffle"] = _shuffle = player.shuffle;
            break;
        case "state":
            unowned string status = map_playback_state();
            if (playback_status == status) {
                return;
            }
            pending_update["PlaybackStatus"] = playback_status = status;
            break;
        case "can-go-next":
            if (can_go_next == player.can_go_next) {
                return;
            }
            pending_update["CanGoNext"] = can_go_next = player.can_go_next;
            break;
        case "can-go-previous":
            if (can_go_previous == player.can_go_previous) {
                return;
            }
            pending_update["CanGoPrevious"] = can_go_previous = player.can_go_previous;
            break;
        case "can-rate":
            if (nuvola_can_rate == player.can_rate) {
                return;
            }
            pending_update["NuvolaCanRate"] = nuvola_can_rate = player.can_rate;
            break;
        case "can-seek":
            if (can_seek == player.can_seek) {
                return;
            }
            pending_update["CanSeek"] = can_seek = player.can_seek;
            break;
        default:
            return;
        }

        if (pending_update_id == 0) {
            pending_update_id = Timeout.add(50, update_cb);
        }
    }

    private bool update_cb() {
        pending_update_id = 0;
        if (pending_update.length == 0) {
            return false;
        }
        var builder = new VariantBuilder(VariantType.ARRAY);
        HashTableIter<string, Variant> iter = HashTableIter<string, Variant>(pending_update);
        unowned string name;
        unowned Variant value;
        while (iter.next(out name, out value)) {
            builder.add("{sv}", name, value);
        }
        pending_update.remove_all();
        var invalid_builder = new VariantBuilder(new VariantType ("as"));
        var payload = new Variant("(sa{sv}as)", "org.mpris.MediaPlayer2.Player", builder, invalid_builder);
        try {
            conn.emit_signal(null, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                payload);
        } catch (Error e) {
            warning("Unable to emit PropertiesChanged signal: %s", e.message);
        }
        return false;
    }

    private HashTable<string, Variant> create_metadata() {
        var metadata = new HashTable<string, Variant>(str_hash, str_equal);
        if (player.artist != null) {
            string[] artistArray = {player.artist};
            metadata.insert("xesam:artist", artistArray);
        }
        if (player.album != null) {
            metadata.insert("xesam:album", player.album);
        }
        if (player.title != null) {
            metadata.insert("xesam:title", player.title);
        }
        if (player.artwork_file != null) {
            metadata.insert("mpris:artUrl", "file://" + player.artwork_file);
        }
        if (player.rating >= 0.0) {
            metadata.insert("xesam:userRating", player.rating);
        }
        if (player.track_length > 0) {
            metadata.insert("mpris:length", new Variant.int64((int64) player.track_length));
        }
        if (metadata.size() > 0) {
            string hash = Checksum.compute_for_string(ChecksumType.MD5, "%s:%s:%s".printf(
                player.title ?? "unknown title",
                player.artist ?? "unknown artist",
                player.album ?? "unknown album"));
            metadata.insert("mpris:trackid", new Variant.string(Nuvola.get_dbus_path() + "/mpris/" + hash));
            // Workaround for a bug eonpatapon/gnome-shell-extensions-mediaplayer#234
            metadata.insert("xesam:genre", new Variant.array(VariantType.STRING, {}));
        }
        return metadata;
    }

    private unowned string map_playback_state() {
        switch (player.state) {
        case "paused":
            return "Paused";
        case "playing":
            return "Playing";
        default:
            return "Stopped";
        }
    }

    private static unowned string map_repeat_state_to_string(PlaybackRepeat repeat) {
        switch (repeat) {
        case PlaybackRepeat.TRACK:
            return "Track";
        case PlaybackRepeat.PLAYLIST:
            return "Playlist";
        default:
            return "None";
        }
    }

    private static PlaybackRepeat map_repeat_state_to_enum(string repeat) {
        switch (repeat) {
        case "Track":
            return PlaybackRepeat.TRACK;
        case "Playlist":
            return PlaybackRepeat.PLAYLIST;
        default:
            return PlaybackRepeat.NONE;
        }
    }
}

} // namespace Nuvola
