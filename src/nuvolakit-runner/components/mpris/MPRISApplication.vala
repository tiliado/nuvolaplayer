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

[DBus(name = "org.mpris.MediaPlayer2")]
public class MPRISApplication: GLib.Object
{
	private Diorite.Application app;
	
	public MPRISApplication(Diorite.Application app)
	{
		this.app = app;
		var desktop_entry = app.desktop_name;
		this.desktop_entry = desktop_entry[0:desktop_entry.length - 8];
	}
	
	/* Properties: http://www.mpris.org/2.1/spec/Root_Node.html#properties */
	public bool can_quit {get{return true;}}
	public bool can_raise {get{ return true;}}
	public bool has_track_list {get{return false;}}
	public string identity {get{ return app.app_name;}}
	public string desktop_entry {get; private set;}
	public string[] supported_uri_schemes {owned get{return {};}}
	public string[] supported_mime_types{owned get{return {};}}
	
	public void raise()
	{
		app.activate();
	}
	
	public void quit()
	{
		app.quit();
	}
}

} // namespace Nuvola
