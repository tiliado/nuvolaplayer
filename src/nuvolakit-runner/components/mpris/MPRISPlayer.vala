/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola
{

[DBus(name = "org.mpris.MediaPlayer2.Player")]
public class MPRISPlayer : GLib.Object
{
	private DBusConnection conn;
	private MediaPlayerModel player;
	private HashTable<string, Variant> pending_update;
	private uint pending_update_id = 0;
	
	public MPRISPlayer(MediaPlayerModel player, DBusConnection conn)
	{
		this.player = player;
		this.conn = conn;
		player.notify.connect_after((o, p) => {schedule_update(p.name);});
		metadata = create_metadata();
		playback_status = map_playback_state();
		pending_update = new HashTable<string, Variant>(str_hash, str_equal);
		can_go_next = player.can_go_next;
		can_go_previous = player.can_go_previous;
		can_play = player.can_play;
		can_pause = player.can_pause;
	}
	
	public string playback_status {get; private set;}
	/* If the media player has no ability to play at speeds other than the normal playback rate,
	 * this must still be implemented, and must return 1.0. The MinimumRate and MaximumRate properties
	 * must also be set to 1.0.  A value of 0.0 set by the client should act as though Pause was called. */
	public double rate
	{
		get
		{
			return 1.0;
		}
		set
		{
			if (value == 0.0)
				pause();
		}
	}
	public double minimum_rate {get{return 1.0;}}
	public double maximum_rate {get{return 1.0;}}
	public bool can_go_next {get; private set; default = false;}
	public bool can_go_previous {get; private set; default = false;}
	public bool can_play {get; private set; default = false;}
	public bool can_pause {get; private set; default = false;}
	public bool can_seek {get; private set; default = false;}
	public bool can_control {get{return true;}}
	public HashTable<string, Variant> metadata {get; private set; default = null;}
	
	public signal void seeked(int64 position);
	
	public void next()
	{
		player.next_song();
	}
	
	public void previous()
	{
		player.prev_song();
	}
	
	public void pause()
	{
		player.pause();
	}
	
	public void play_pause()
	{
		player.toggle_play();
	}
	
	public void stop()
	{
		player.stop();
	}
	
	public void play()
	{
		player.play();
	}
	
	public void seek(int64 offset)
	{
	}
	
	public void set_position(string track_id, int64 position)
	{
	}
	
	public void open_uri(string uri)
	{
	}
	
	private void schedule_update(string param)
	{
		switch (param)
		{
		case "title":
		case "artist":
		case "album":
		case "artwork-file":
		case "rating":
			var new_metadata = create_metadata();
			if (new_metadata.size() == 0 && metadata.size() == 0)
				return;
			pending_update["Metadata"] = metadata = new_metadata;
			break;
		case "state":
			var status = map_playback_state();
			if (playback_status == status)
				return;
			pending_update["PlaybackStatus"] = playback_status = status;
			break;
		case "can-go-next":
			if (can_go_next == player.can_go_next)
				return;
			pending_update["CanGoNext"] = can_go_next = player.can_go_next;
			break;
		case "can-go-previous":
			if (can_go_previous == player.can_go_previous)
				return;
			pending_update["CanGoPrevious"] = can_go_previous = player.can_go_previous;
			break;
		case "can-play":
			if (can_play == player.can_play)
				return;
			pending_update["CanPlay"] = can_play = player.can_play;
			break;
		case "can-pause":
			if (can_pause == player.can_pause)
				return;
			pending_update["CanPause"] = can_pause = player.can_pause;
			break;
		default:
			return;
		}
		
		if (pending_update_id == 0)
			pending_update_id = Timeout.add(300, update_cb);
	}
	
	private bool update_cb()
	{
		pending_update_id = 0;
		var builder = new VariantBuilder(VariantType.ARRAY);
		var iter = HashTableIter<string, Variant>(pending_update);
		unowned string name;
		unowned Variant value;
		while (iter.next(out name, out value))
			builder.add("{sv}", name, value);
		pending_update.remove_all();
		var invalid_builder = new VariantBuilder(new VariantType ("as"));
		var payload = new Variant("(sa{sv}as)", "org.mpris.MediaPlayer2.Player", builder, invalid_builder);
		try
		{
			conn.emit_signal(null, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
				payload);
		}
		catch (Error e)
		{
			warning("Unable to emit PropertiesChanged signal: %s", e.message);
		}
		return false;
	}
	
	private HashTable<string,Variant> create_metadata()
	{
		var metadata = new HashTable<string,Variant>(str_hash, str_equal);
		if(player.artist != null)
		{
			string[] artistArray = {player.artist};
			metadata.insert("xesam:artist", artistArray);
		}
		if (player.album != null)
			metadata.insert("xesam:album", player.album);
		if (player.title != null)
			metadata.insert("xesam:title", player.title);
		if (player.artwork_file != null)
			metadata.insert("mpris:artUrl", "file://" + player.artwork_file);
		if (player.rating >= 0.0)
			metadata.insert("xesam:userRating", player.rating);
			
		if (metadata.size() > 0)
		{
			metadata.insert("mpris:trackid", new Variant.string("1"));
			// Workaround for a bug eonpatapon/gnome-shell-extensions-mediaplayer#234
			metadata.insert("xesam:genre", new Variant.array(VariantType.STRING, {}));
		}
		return metadata;
	}
	
	private string map_playback_state()
	{
		switch (player.state)
		{
		case "paused":
			return "Paused";
		case "playing":
			return "Playing";
		default:
			return "Stopped";
		}
	}
}

} // namespace Nuvola
