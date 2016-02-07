/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

using Diorite;

public class Nuvola.MediaPlayerBinding: ModelBinding<MediaPlayerModel>
{
	public MediaPlayerBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker, MediaPlayerModel model)
	{
		base(server, web_worker, "Nuvola.MediaPlayer", model);
	}
	
	protected override void bind_methods()
	{
		bind("setFlag", handle_set_flag);
		bind("setTrackInfo", handle_set_track_info);
		bind("getTrackInfo", handle_get_track_info);
	}
	
	private Variant? handle_set_track_info(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(@a{smv})");
		Variant dict;
		data.get("(@a{smv})", out dict);
		var title = variant_dict_str(dict, "title");
		var artist = variant_dict_str(dict, "artist");
		var album = variant_dict_str(dict, "album");
		var state = variant_dict_str(dict, "state");
		var artwork_location = variant_dict_str(dict, "artworkLocation");
		var artwork_file = variant_dict_str(dict, "artworkFile");
		var rating = variant_dict_double(dict, "rating", 0.0);
		model.set_track_info(title, artist, album, state, artwork_location, artwork_file, rating);
		
		SList<string> playback_actions = null;
		var actions = Diorite.variant_to_strv(dict.lookup_value("playbackActions", null).get_maybe().get_variant());
		foreach (var action in actions)
			playback_actions.prepend(action);
		
		playback_actions.reverse();
		model.playback_actions = (owned) playback_actions;
		return new Variant.boolean(true);
	}
	
	private Variant? handle_get_track_info(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		var builder = new VariantBuilder(new VariantType("a{sms}"));
		builder.add("{sms}", "title", model.title);
		builder.add("{sms}", "artist", model.artist);
		builder.add("{sms}", "album", model.album);
		builder.add("{sms}", "state", model.state);
		builder.add("{sms}", "artworkLocation", model.artwork_location);
		builder.add("{sms}", "artworkFile", model.artwork_file);
		return builder.end();
	}
	
	private Variant? handle_set_flag(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(sb)");
		bool handled = false;
		string name;
		bool val;
		data.get("(sb)", out name, out val);
		switch (name)
		{
		case "can-go-next":
		case "can-go-previous":
		case "can-play":
		case "can-pause":
		case "can-stop":
			handled = true;
			GLib.Value value = GLib.Value(typeof(bool));
			value.set_boolean(val);
			model.@set_property(name, value);
			break;
		default:
			critical("Unknown flag '%s'", name);
			break;
		}
		return new Variant.boolean(handled);
	}
}
