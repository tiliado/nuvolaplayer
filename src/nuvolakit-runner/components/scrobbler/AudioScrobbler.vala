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

namespace Nuvola
{


public errordomain AudioScrobblerError
{
	NOT_IMPLEMENTED,
	CONNECTION_ERROR,
	NOT_AUTHENTICATED,
	JSON_PARSE_ERROR,
	LASTFM_ERROR,
	WRONG_RESPONSE,
	NO_SESSION,
	RETRY
}


public abstract class AudioScrobbler : GLib.Object
{
	public string id {get; protected construct;}
	public string name {get; protected construct;}
	public bool has_settings {get; protected set; default = false;}
	public bool scrobbling_enabled {get; set; default = false;}
	public bool can_scrobble {get; protected set; default = false;}
	public bool can_update_now_playing {get; protected set; default = false;}
	
	public virtual Gtk.Widget? get_settings(Drtgtk.Application app)
	{
		return null;
	}
	
	public virtual async void scrobble_track(string song, string artist, string? album, int64 timestamp)
		throws AudioScrobblerError
	{
		throw new AudioScrobblerError.NOT_IMPLEMENTED("Scrobble track call is not implemented in %s (%s).", name, id);
	}
	
	public virtual async void update_now_playing(string song, string artist) throws AudioScrobblerError
	{
		throw new AudioScrobblerError.NOT_IMPLEMENTED("Update now playing call is not implemented in %s (%s).", name, id);
	}
}


} // namespace Nuvola
