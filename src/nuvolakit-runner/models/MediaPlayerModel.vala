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

public interface Nuvola.MediaPlayerModel: GLib.Object
{
	public abstract string? title {get; set; default = null;}
	public abstract string? artist {get; set; default = null;}
	public abstract string? album {get; set; default = null;}
	public abstract string? state {get; set; default = null;}
	public abstract string? artwork_location {get; set; default = null;}
	public abstract string? artwork_file {get; set; default = null;}
	public abstract bool can_go_next {get; set;}
	public abstract bool can_go_previous {get; set;}
	public abstract bool can_play {get; set;}
	public abstract bool can_pause {get; set;}
	
	public virtual signal void set_track_info(string? title, string? artist, string? album, string? state, string? artwork_location, string? artwork_file)
	{
		handle_set_track_info(title, artist, album, state, artwork_location, artwork_file);
	}
	
	protected abstract void handle_set_track_info(string? title, string? artist, string? album, string? state, string? artwork_location, string? artwork_file);
	
	public abstract void play();
	
	public abstract void pause();
	
	public abstract void toggle_play();
	
	public abstract void stop();
	
	public abstract void prev_song();
	
	public abstract void next_song();
}
