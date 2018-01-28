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

public class MPRISProvider {
    private MediaPlayerModel player;
    private uint owner_id = 0;
    private Drtgtk.Application app;
    private MPRISApplication? mpris_app = null;
    private MPRISPlayer? mpris_player = null;
    private DBusConnection? conn = null;
    private uint[] registered_objects = new uint[2];

    public MPRISProvider(Drtgtk.Application app, MediaPlayerModel player) {
        this.player = player;
        this.app = app;
    }

    public void start() {
        string app_id = app.application_id;
        string bus_name = "org.mpris.MediaPlayer2." + app_id.substring(app_id.last_index_of_char('.') + 1);
        // Watch out! Bus.own_name takes three references!
        owner_id = Bus.own_name(BusType.SESSION, bus_name, BusNameOwnerFlags.NONE,
            on_bus_acquired, on_name_acquired, on_name_lost);
        if (owner_id == 0)
        critical("Unable to obtain bus name %s", bus_name);
    }

    public void stop() {
        if (owner_id > 0) {
            Bus.unown_name(owner_id);
            owner_id = 0;
        }

        if (conn != null) {
            foreach (uint registration_id in registered_objects)
            conn.unregister_object(registration_id);
            conn = null;
        }
    }

    private void on_bus_acquired(DBusConnection conn, string name) {
        debug("Bus acquired: %s, registering objects", name);
        mpris_app = new MPRISApplication(app);
        mpris_player = new MPRISPlayer(player, conn);
        try {
            registered_objects[0] = conn.register_object("/org/mpris/MediaPlayer2", mpris_app);
            registered_objects[1] = conn.register_object("/org/mpris/MediaPlayer2", mpris_player);
            this.conn = conn;
        }
        catch(IOError e) {
            critical("Unable to register objects: %s", e.message);
        }
    }

    private void on_name_acquired(DBusConnection connection, string name) {
        debug("Bus name acquired: %s", name);
    }

    private void on_name_lost(DBusConnection connection, string name) {
        critical("Bus name lost: %s", name);
    }
}

} // namespace Nuvola
