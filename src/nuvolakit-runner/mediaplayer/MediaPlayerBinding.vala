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

using Diorite;

public class Nuvola.MediaPlayerBinding: Binding<MediaPlayerInterface>
{
	public MediaPlayerBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker)
	{
		base(server, web_worker, "Nuvola.MediaPlayer");
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
		
		bool handled = false;
		foreach (var object in objects)
			if (handled = object.set_track_info(title, artist, album, state, artwork_location, artwork_file))
				break;
		
		return new Variant.boolean(handled);
	}
	
	private Variant? handle_get_track_info(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		
		string? title = null;
		string? artist = null;
		string? album = null;
		string? state = null;
		string? artwork_location = null;
		string? artwork_file = null;
		foreach (var object in objects)
			if (object.get_track_info(ref title, ref artist, ref album, ref state, ref artwork_location, ref artwork_file))
				break;
		
		var builder = new VariantBuilder(new VariantType("a{sms}"));
		builder.add("{sms}", "title", title);
		builder.add("{sms}", "artist", artist);
		builder.add("{sms}", "album", album);
		builder.add("{sms}", "state", state);
		builder.add("{sms}", "artworkLocation", artwork_location);
		builder.add("{sms}", "artworkFile", artwork_file);
		return builder.end();
	}
	
	private Variant? handle_set_flag(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		check_not_empty();
		Diorite.Ipc.MessageServer.check_type_str(data, "(sb)");
		string name;
		bool val;
		data.get("(sb)", out name, out val);
		bool handled = false;
		switch (name)
		{
		case "can-go-next":
		case "can-go-previous":
		case "can-play":
		case "can-pause":
			handled = true;
			Value value = Value(typeof(bool));
			value.set_boolean(val);
			foreach (var object in objects)
				object.@set_property(name, value);
			break;
		default:
			critical("Unknown flag '%s'", name);
			break;
		}
		return new Variant.boolean(handled);
	}
}
