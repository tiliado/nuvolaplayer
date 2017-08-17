/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class AudioScrobblerComponent: Component
{
	private const int SCROBBLE_SONG_DELAY = 60;
	
	private Bindings bindings;
	private Drtgtk.Application app;
	private Soup.Session connection;
	private unowned Drt.KeyValueStorage config;
	private unowned Drt.KeyValueStorage global_config;
	private AudioScrobbler? scrobbler = null;
	private MediaPlayerModel? player = null;
	private uint scrobble_timeout = 0;
	private string? scrobble_title = null;
	private string? scrobble_artist = null;
	private string? scrobble_album = null;
	private bool scrobbled = false;
	private uint track_info_cb_id = 0;
	
	public AudioScrobblerComponent(
		Drtgtk.Application app, Bindings bindings, Drt.KeyValueStorage global_config, Drt.KeyValueStorage config, Soup.Session connection)
	{
		base("scrobbler", "Audio Scrobbler Services", "Integration with audio scrobbling services like Last FM and Libre FM.");
		this.bindings = bindings;
		this.app = app;
		this.global_config = global_config;
		this.config = config;
		this.connection = connection;
		has_settings = true;
		config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(true).update_property();
		auto_activate = false;
	}
	
	public override Gtk.Widget? get_settings()
	{
		if (scrobbler == null)
			return null;
			
		var grid = new Gtk.Grid();
		grid.orientation = Gtk.Orientation.VERTICAL;
		var label = new Gtk.Label(Markup.printf_escaped("<b>%s</b>", scrobbler.name));
		label.use_markup = true;
		label.vexpand = false;
		label.hexpand = true;
		grid.add(label);
		var widget = scrobbler.get_settings(app);
		if (widget != null)
			grid.add(widget);
		grid.show_all();
		return grid;
	}
	
	protected override bool activate()
	{
		var scrobbler = new LastfmScrobbler(connection);
		this.scrobbler = scrobbler;
		var base_key = "component.%s.%s.".printf(id, scrobbler.id);
		config.bind_object_property(base_key, scrobbler, "scrobbling_enabled").set_default(true).update_property();
		global_config.bind_object_property(base_key, scrobbler, "session").update_property();
		global_config.bind_object_property(base_key, scrobbler, "username").update_property();
		
		if (scrobbler.has_session)
			scrobbler.retrieve_username.begin();
		player = bindings.get_model<MediaPlayerModel>();
		player.set_track_info.connect(on_set_track_info);
		scrobbler.notify.connect_after(on_scrobbler_notify);
		on_set_track_info(player.title, player.artist, player.album, player.state);
		return true;
	}
	
	protected override bool deactivate()
	{
		scrobbler.notify.disconnect(on_scrobbler_notify);
		scrobbler = null;
		player.set_track_info.disconnect(on_set_track_info);
		player = null;
		cancel_scrobbling();
		scrobble_title = null;
		scrobble_artist = null;
		scrobble_album = null;
		scrobbled = false;
		return true;
	}
	
	private void schedule_scrobbling(string? title, string? artist, string? album, string? state)
	{
		if (scrobble_timeout == 0 && title != null && artist != null && state == "playing")
		{
			if (scrobble_title != title || scrobble_artist != artist)
			{
				scrobble_title = title;
				scrobble_artist = artist;
				scrobble_album = album;
				scrobbled = false;
			}
			
			if (!scrobbled)
				scrobble_timeout = Timeout.add_seconds(SCROBBLE_SONG_DELAY, scrobble_cb);
		}
	}
	
	private void cancel_scrobbling()
	{
		if (scrobble_timeout != 0)
		{
			Source.remove(scrobble_timeout);
			scrobble_timeout = 0;
		}
	}
	
	private void on_scrobbler_notify(GLib.Object o, ParamSpec p)
	{
		var scrobbler = o as AudioScrobbler;
		return_if_fail(scrobbler != null);
		switch (p.name)
		{
		case "can-update-now-playing":
			if (scrobbler.can_update_now_playing)
			{
				if (player.title != null && player.artist != null && player.state == "playing")
					scrobbler.update_now_playing.begin(player.title, player.artist, on_update_now_playing_done);
			}
			break;
		case "can-scrobble":
			if (scrobbler.can_scrobble)
				schedule_scrobbling(player.title, player.artist, player.album, player.state);
			else
				cancel_scrobbling();
			break;
		}
	}
	
	private void on_set_track_info(
		string? title, string? artist, string? album, string? state)
	{
		
		if (track_info_cb_id != 0)
		{
			Source.remove(track_info_cb_id);
			track_info_cb_id = 0;
		}
		
		track_info_cb_id = Timeout.add_seconds(1, () =>
		{
			track_info_cb_id = 0;
			if (scrobbler.can_update_now_playing)
			{
				if (title != null && artist != null && state == "playing" )
					scrobbler.update_now_playing.begin(title, artist, on_update_now_playing_done);
			}
			
			cancel_scrobbling();
			
			if (scrobbler.can_scrobble)
				schedule_scrobbling(title, artist, album, state);
			return false;
		});
	}
	
	private void on_update_now_playing_done(GLib.Object? o, AsyncResult res)
	{
		var scrobbler = o as AudioScrobbler;
		return_if_fail(scrobbler != null);
		try
		{
			scrobbler.update_now_playing.end(res);
		}
		catch (AudioScrobblerError e)
		{
			warning("Update now playing failed for %s (%s): %s", scrobbler.name, scrobbler.id, e.message);
			app.show_warning(
				"%s Error".printf(scrobbler.name),
				"Failed to update information about now playing track and this functionality has been disabled");
			scrobbler.scrobbling_enabled = false;
		}
	}
	
	private bool scrobble_cb()
	{
		scrobble_timeout = 0;
		if (scrobbler.can_scrobble)
		{
			scrobbled = true;
			var datetime = new DateTime.now_utc();
			scrobbler.scrobble_track.begin(
				scrobble_title, scrobble_artist, scrobble_album, datetime.to_unix(), on_scrobble_track_done);
		}
		return false;
	}
	
	private void on_scrobble_track_done(GLib.Object? o, AsyncResult res)
	{
		var scrobbler = o as AudioScrobbler;
		return_if_fail(scrobbler != null);
		try
		{
			scrobbler.scrobble_track.end(res);
		}
		catch (AudioScrobblerError e)
		{
			warning("Scrobbling failed for %s (%s): %s", scrobbler.name, scrobbler.id, e.message);
			app.show_warning(
				"%s Error".printf(scrobbler.name),
				"Failed to scrobble track. This functionality has been disabled");
			scrobbler.scrobbling_enabled = false;
		}
	}
}

} // namespace Nuvola
