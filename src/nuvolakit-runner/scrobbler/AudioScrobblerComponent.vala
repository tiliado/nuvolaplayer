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

public class AudioScrobblerComponent: Component
{
	private Bindings bindings;
	private Diorite.Application app;
	private Soup.Session connection;
	private unowned Diorite.KeyValueStorage config;
	private AudioScrobbler? scrobbler = null;
	private MediaPlayerModel? player = null;
	
	public AudioScrobblerComponent(
		Diorite.Application app, Bindings bindings, Diorite.KeyValueStorage config, Soup.Session connection)
	{
		base("scrobbler", "Audio Scrobbler Services", "Integration with audio scrobbling services like Last FM and Libre FM.");
		this.bindings = bindings;
		this.app = app;
		this.config = config;
		this.connection = connection;
		has_settings = true;
		config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(true).update_property();
		enabled_set = true;
		if (enabled)
			activate();
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
	
	protected override void activate()
	{
		var scrobbler = new LastfmScrobbler(connection, config);
		this.scrobbler = scrobbler;
		if (scrobbler.has_session)
			scrobbler.retrieve_username.begin();
		player = bindings.get_model<MediaPlayerModel>();
		player.set_track_info.connect(on_set_track_info);
		on_set_track_info(player.title, player.artist, player.album, player.state);
	}
	
	protected override void deactivate()
	{
		scrobbler = null;
		player.set_track_info.disconnect(on_set_track_info);
		player = null;
	}
	
	private void on_set_track_info(
		string? title, string? artist, string? album, string? state)
	{
		if (scrobbler.can_update_now_playing)
		{
			if (title != null && artist != null && state == "playing" )
				scrobbler.update_now_playing.begin(title, artist, on_update_now_playing_done);
		}
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
			scrobbler.can_update_now_playing = false;
		}
	}
}

} // namespace Nuvola
